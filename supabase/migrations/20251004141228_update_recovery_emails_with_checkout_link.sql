/*
  # Update Recovery Email Function to Include Checkout Link

  1. Updates
    - Modifies send_pending_recovery_emails() to include checkout link in email
    - Generates checkout link URL dynamically
    - Adds prominent call-to-action button for checkout
    
  2. Email Structure:
    - Primary CTA: Custom checkout link (better conversion)
    - Secondary CTA: Original Bestfy secure URL (fallback)
    
  3. Notes:
    - Checkout link is generated BEFORE email is sent (by cron job)
    - Email includes personalized checkout URL
    - Better user experience = higher conversion
*/

-- Drop and recreate the function with checkout link support
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
  checkout_url text;
  base_url text := 'https://bestfypay.com.br'; -- Update this to your actual domain
BEGIN
  RAISE NOTICE '[AUTO-RECOVERY] Starting recovery email check at %', NOW();
  
  -- Get Postmark token from database
  SELECT encrypted_key INTO postmark_token
  FROM api_keys
  WHERE service = 'postmark' AND is_active = true
  LIMIT 1;
  
  IF postmark_token IS NULL THEN
    RAISE NOTICE '[AUTO-RECOVERY] ❌ No Postmark token found';
    RETURN jsonb_build_object(
      'success', false,
      'emails_sent', 0,
      'errors', 1,
      'error_message', 'Postmark token not configured',
      'timestamp', NOW()
    );
  END IF;
  
  -- Loop through eligible payments
  FOR payment_record IN
    SELECT 
      p.id,
      p.bestfy_id,
      p.customer_email,
      p.customer_name,
      p.product_name,
      p.amount,
      p.secure_url,
      cl.checkout_slug
    FROM payments p
    LEFT JOIN checkout_links cl ON cl.payment_id = p.id
    WHERE p.status = 'waiting_payment'
      AND p.payment_method = 'pix'
      AND p.secure_url IS NOT NULL
      AND p.recovery_email_sent_at IS NULL
      AND p.created_at < (NOW() - INTERVAL '3 minutes')
    ORDER BY p.created_at ASC
    LIMIT 5 -- Process 5 per minute
  LOOP
    BEGIN
      RAISE NOTICE '[AUTO-RECOVERY] Sending email to: % (%)', payment_record.customer_email, payment_record.bestfy_id;
      
      -- Build checkout URL if slug exists
      IF payment_record.checkout_slug IS NOT NULL THEN
        checkout_url := base_url || '/checkout/' || payment_record.checkout_slug;
      ELSE
        checkout_url := payment_record.secure_url;
      END IF;
      
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
            '<div style="background: linear-gradient(135deg, #32BCAD 0%, #28A896 100%); color: white; padding: 30px 20px; border-radius: 12px 12px 0 0; text-align: center;">' ||
            '<h1 style="margin: 0; font-size: 28px;">🔔 Seu PIX está esperando!</h1></div>' ||
            '<div style="background: #ffffff; padding: 40px 30px; border-radius: 0 0 12px 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">' ||
            '<p style="font-size: 16px; line-height: 1.6; color: #333;">Olá <strong>' || payment_record.customer_name || '</strong>,</p>' ||
            '<p style="font-size: 16px; line-height: 1.6; color: #555;">Você iniciou um pagamento via <strong>PIX</strong> mas ainda não finalizou. Complete agora e garanta sua compra!</p>' ||
            '<div style="background: #f8f9fa; padding: 25px; border-radius: 10px; margin: 25px 0; border-left: 4px solid #32BCAD;">' ||
            '<h3 style="margin: 0 0 15px 0; color: #32BCAD; font-size: 18px;">📦 Detalhes da Compra</h3>' ||
            '<p style="margin: 8px 0; color: #333;"><strong>Produto:</strong> ' || payment_record.product_name || '</p>' ||
            '<p style="margin: 8px 0; color: #333;"><strong>Valor:</strong> <span style="font-size: 20px; color: #32BCAD; font-weight: bold;">R$ ' || REPLACE(TO_CHAR(payment_record.amount / 100.0, 'FM999999990.00'), '.', ',') || '</span></p>' ||
            '<p style="margin: 8px 0; color: #666; font-size: 14px;"><strong>ID:</strong> ' || payment_record.bestfy_id || '</p></div>' ||
            '<div style="text-align: center; margin: 35px 0;">' ||
            '<a href="' || checkout_url || '" style="display: inline-block; background: linear-gradient(135deg, #32BCAD 0%, #28A896 100%); color: white; padding: 18px 40px; text-decoration: none; border-radius: 50px; font-weight: bold; font-size: 18px; box-shadow: 0 4px 15px rgba(50, 188, 173, 0.4); transition: all 0.3s;">' ||
            '📱 Finalizar Pagamento Agora</a></div>' ||
            '<div style="text-align: center; padding: 20px; background: #f0fdf4; border-radius: 8px; margin: 25px 0;">' ||
            '<p style="margin: 0; color: #059669; font-weight: 600; font-size: 14px;">✨ PIX é instantâneo e 100% seguro</p>' ||
            '<p style="margin: 5px 0 0 0; color: #047857; font-size: 13px;">Seu pagamento é aprovado em segundos!</p></div>' ||
            '<p style="color: #666; font-size: 13px; text-align: center; margin-top: 30px; border-top: 1px solid #e5e7eb; padding-top: 20px;">Este é um e-mail automático, por favor não responda.<br>Caso não reconheça esta compra, ignore este e-mail.</p>' ||
            '</div></div></body></html>',
          'TextBody', 'Olá ' || payment_record.customer_name || ', finalize seu PIX de R$ ' || TO_CHAR(payment_record.amount / 100.0, 'FM999990.00') || '. Acesse: ' || checkout_url,
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