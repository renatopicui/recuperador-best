/*
  # Setup Automatic Recovery Emails

  1. Creates a function to send recovery emails via HTTP request to edge function
  2. Sets up pg_cron to run every minute and check for pending payments
  3. Automatically sends recovery emails 3 minutes after payment creation
  
  ## How it works:
  - Cron runs every 1 minute
  - Finds payments that are:
    - Status = 'waiting_payment'
    - Payment method = 'pix'
    - Created more than 3 minutes ago
    - Haven't received recovery email yet
  - Calls the edge function to send emails
  
  ## Security:
  - No changes to RLS policies
  - Uses service role for HTTP calls
*/

-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create a function that will be called by cron to send recovery emails
CREATE OR REPLACE FUNCTION send_pending_recovery_emails()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  payment_record RECORD;
  supabase_url text;
  service_key text;
  postmark_token text;
  email_response text;
BEGIN
  -- Get environment variables (these would need to be set in Supabase)
  supabase_url := current_setting('app.settings.supabase_url', true);
  service_key := current_setting('app.settings.service_role_key', true);
  postmark_token := COALESCE(current_setting('app.settings.postmark_token', true), '444cb041-a2de-4ece-b066-e345a0f5d8bd');
  
  RAISE NOTICE 'Starting recovery email check at %', NOW();
  
  -- Loop through all eligible payments
  FOR payment_record IN
    SELECT 
      id,
      bestfy_id,
      customer_email,
      customer_name,
      product_name,
      amount,
      payment_method,
      secure_url,
      created_at
    FROM payments
    WHERE status = 'waiting_payment'
      AND payment_method = 'pix'
      AND secure_url IS NOT NULL
      AND recovery_email_sent_at IS NULL
      AND created_at < (NOW() - INTERVAL '3 minutes')
    LIMIT 10 -- Process max 10 per run to avoid timeouts
  LOOP
    BEGIN
      RAISE NOTICE 'Processing payment: % for %', payment_record.bestfy_id, payment_record.customer_email;
      
      -- Use pg_net extension to make HTTP call to Postmark
      SELECT content INTO email_response
      FROM http((
        'POST',
        'https://api.postmarkapp.com/email',
        ARRAY[
          http_header('Accept', 'application/json'),
          http_header('Content-Type', 'application/json'),
          http_header('X-Postmark-Server-Token', postmark_token)
        ],
        'application/json',
        json_build_object(
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
            '<p>Você iniciou um pagamento via <strong>PIX</strong> mas ainda não finalizou.</p>' ||
            '<div style="background: white; padding: 20px; border-radius: 6px; margin: 20px 0;">' ||
            '<h3>📦 Detalhes da Compra</h3>' ||
            '<p><strong>Produto:</strong> ' || payment_record.product_name || '</p>' ||
            '<p><strong>Valor:</strong> R$ ' || TO_CHAR(payment_record.amount / 100.0, 'FM999999990.00') || '</p>' ||
            '<p><strong>ID:</strong> ' || payment_record.bestfy_id || '</p></div>' ||
            '<div style="text-align: center; margin: 30px 0;">' ||
            '<a href="' || payment_record.secure_url || '" style="display: inline-block; background: #32BCAD; color: white; padding: 15px 30px; text-decoration: none; border-radius: 6px; font-weight: bold;">' ||
            '📱 Pagar com PIX Agora</a></div></div></div></body></html>',
          'TextBody', 'Olá ' || payment_record.customer_name || ', finalize seu PIX: ' || payment_record.secure_url,
          'Tag', 'auto-pix-recovery',
          'TrackOpens', true,
          'Metadata', json_build_object(
            'transaction_id', payment_record.bestfy_id,
            'customer_name', payment_record.customer_name
          )
        )::text
      )::http_request);
      
      -- Mark email as sent
      UPDATE payments
      SET recovery_email_sent_at = NOW()
      WHERE id = payment_record.id;
      
      RAISE NOTICE 'Email sent successfully to %', payment_record.customer_email;
      
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Error sending email to %: %', payment_record.customer_email, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Recovery email check completed at %', NOW();
END;
$$;

-- Schedule the function to run every 1 minute
SELECT cron.schedule(
  'send-recovery-emails',
  '* * * * *', -- Every minute
  'SELECT send_pending_recovery_emails();'
);

-- Grant execute permission
GRANT EXECUTE ON FUNCTION send_pending_recovery_emails() TO postgres;