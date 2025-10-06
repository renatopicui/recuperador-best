/*
  # Fix Recovery Emails - Use Correct Column Name

  1. Updates function to use 'encrypted_key' column instead of 'api_key'
  2. Ensures proper token retrieval from database
*/

DROP FUNCTION IF EXISTS send_pending_recovery_emails();

CREATE OR REPLACE FUNCTION send_pending_recovery_emails()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  payment_record RECORD;
  postmark_token text;
  request_id bigint;
  email_count int := 0;
  error_count int := 0;
BEGIN
  RAISE NOTICE '[AUTO-RECOVERY] Starting recovery email check at %', NOW();
  
  -- Get Postmark token from database (using correct column name)
  SELECT encrypted_key INTO postmark_token
  FROM api_keys
  WHERE service = 'postmark'
    AND is_active = true
  LIMIT 1;
  
  -- Check if token exists
  IF postmark_token IS NULL THEN
    RAISE NOTICE '[AUTO-RECOVERY] ❌ No Postmark token configured in api_keys table';
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No Postmark API key configured',
      'emails_sent', 0,
      'timestamp', NOW()
    );
  END IF;
  
  RAISE NOTICE '[AUTO-RECOVERY] ✅ Postmark token found: %...', LEFT(postmark_token, 8);
  
  -- Loop through eligible payments
  FOR payment_record IN
    SELECT 
      id,
      bestfy_id,
      customer_email,
      customer_name,
      product_name,
      amount,
      secure_url
    FROM payments
    WHERE status = 'waiting_payment'
      AND payment_method = 'pix'
      AND secure_url IS NOT NULL
      AND recovery_email_sent_at IS NULL
      AND created_at < (NOW() - INTERVAL '3 minutes')
    ORDER BY created_at ASC
    LIMIT 5 -- Process 5 per minute
  LOOP
    BEGIN
      RAISE NOTICE '[AUTO-RECOVERY] 📧 Sending email to: % (%)', payment_record.customer_email, payment_record.bestfy_id;
      
      -- Make async HTTP request to Postmark
      SELECT net.http_post(
        url := 'https://api.postmarkapp.com/email',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Accept', 'application/json',
          'X-Postmark-Server-Token', postmark_token
        ),
        body := jsonb_build_object(
          'From', 'Bestfy Pay <noreply@onabetbr.live>',
          'To', payment_record.customer_email,
          'Subject', '🔔 ' || payment_record.customer_name || ', finalize seu PIX - ' || payment_record.product_name,
          'HtmlBody', 
            '<!DOCTYPE html><html><body style="font-family: Arial, sans-serif;">' ||
            '<div style="max-width: 600px; margin: 0 auto; padding: 20px;">' ||
            '<div style="background: #32BCAD; color: white; padding: 20px; border-radius: 8px 8px 0 0; text-align: center;">' ||
            '<h1>🔔 Seu PIX está esperando!</h1></div>' ||
            '<div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px;">' ||
            '<p>Olá <strong>' || payment_record.customer_name || '</strong>,</p>' ||
            '<p>Você iniciou um pagamento via <strong>PIX</strong> mas ainda não finalizou. Complete agora e garanta sua compra!</p>' ||
            '<div style="background: white; padding: 20px; border-radius: 6px; margin: 20px 0;">' ||
            '<h3>📦 Detalhes da Compra</h3>' ||
            '<p><strong>Produto:</strong> ' || payment_record.product_name || '</p>' ||
            '<p><strong>Valor:</strong> R$ ' || REPLACE(TO_CHAR(payment_record.amount / 100.0, 'FM999999990.00'), '.', ',') || '</p>' ||
            '<p><strong>ID:</strong> ' || payment_record.bestfy_id || '</p></div>' ||
            '<div style="text-align: center; margin: 30px 0;">' ||
            '<a href="' || payment_record.secure_url || '" style="display: inline-block; background: #32BCAD; color: white; padding: 15px 30px; text-decoration: none; border-radius: 6px; font-weight: bold; font-size: 16px;">' ||
            '📱 Pagar com PIX Agora</a></div>' ||
            '<p style="color: #666; font-size: 14px; text-align: center; margin-top: 30px;">PIX é instantâneo e 100% seguro!</p>' ||
            '</div></div></body></html>',
          'TextBody', 'Olá ' || payment_record.customer_name || ', finalize seu PIX de R$ ' || TO_CHAR(payment_record.amount / 100.0, 'FM999990.00') || '. Acesse: ' || payment_record.secure_url,
          'Tag', 'auto-pix-recovery',
          'TrackOpens', true
        )
      ) INTO request_id;
      
      -- Mark email as sent immediately (pg_net is async, we trust it will work)
      UPDATE payments
      SET recovery_email_sent_at = NOW()
      WHERE id = payment_record.id;
      
      email_count := email_count + 1;
      
      RAISE NOTICE '[AUTO-RECOVERY] ✅ Email queued for % (request_id: %)', payment_record.customer_email, request_id;
      
    EXCEPTION WHEN OTHERS THEN
      error_count := error_count + 1;
      RAISE NOTICE '[AUTO-RECOVERY] ❌ Error for %: %', payment_record.customer_email, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE '[AUTO-RECOVERY] Completed: % sent, % errors', email_count, error_count;
  
  RETURN jsonb_build_object(
    'success', true,
    'emails_sent', email_count,
    'errors', error_count,
    'timestamp', NOW()
  );
END;
$$;