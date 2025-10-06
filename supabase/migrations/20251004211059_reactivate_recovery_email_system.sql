/*
  # Reativar Sistema de Recuperação de Emails Automático

  1. Objetivo
    - Reativar o envio automático de emails de recuperação de vendas
    - Emails são enviados para pagamentos PIX pendentes após 3 minutos

  2. Como funciona
    - Um cron job roda a cada 1 minuto
    - Busca pagamentos com:
      * Status = 'waiting_payment'
      * Método = 'pix'
      * Criados há mais de 3 minutos
      * Que ainda não receberam email de recuperação
    - Envia email via pg_net (Postmark API)
    - Marca o pagamento como "email enviado"

  3. Segurança
    - Função com SECURITY DEFINER (privilégios elevados)
    - Sem mudanças nas políticas RLS
*/

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Drop existing cron job if it exists
DO $$
BEGIN
  PERFORM cron.unschedule('send-recovery-emails');
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- Drop old function if exists
DROP FUNCTION IF EXISTS send_pending_recovery_emails();

-- Create function to send recovery emails
CREATE OR REPLACE FUNCTION send_pending_recovery_emails()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  payment_record RECORD;
  postmark_token text := '444cb041-a2de-4ece-b066-e345a0f5d8bd';
  request_id bigint;
  email_count int := 0;
  error_count int := 0;
BEGIN
  RAISE NOTICE '[AUTO-RECOVERY] Starting recovery email check at %', NOW();
  
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
    LIMIT 5 -- Process 5 per minute to avoid overwhelming the system
  LOOP
    BEGIN
      RAISE NOTICE '[AUTO-RECOVERY] Sending email to: % (%)', payment_record.customer_email, payment_record.bestfy_id;
      
      -- Make async HTTP request to Postmark via pg_net
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
            '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Complete seu PIX</title></head>' ||
            '<body style="font-family: Arial, sans-serif; margin: 0; padding: 0; background-color: #f4f4f4;">' ||
            '<div style="max-width: 600px; margin: 0 auto; background-color: white;">' ||
            '<div style="background: linear-gradient(135deg, #32BCAD 0%, #14B8A6 100%); color: white; padding: 30px 20px; text-align: center;">' ||
            '<h1 style="margin: 0; font-size: 28px;">🔔 Seu PIX está esperando!</h1></div>' ||
            '<div style="padding: 30px 20px;">' ||
            '<div style="background: #FEF3C7; border-left: 4px solid #F59E0B; padding: 15px; margin-bottom: 25px;">' ||
            '<p style="margin: 0; font-weight: bold; color: #92400E;">⏰ Seu pagamento PIX está pendente</p></div>' ||
            '<p style="font-size: 16px; line-height: 1.6; color: #333;">Olá <strong>' || payment_record.customer_name || '</strong>,</p>' ||
            '<p style="font-size: 16px; line-height: 1.6; color: #333;">Você iniciou um pagamento via <strong>PIX</strong> mas ainda não finalizou. O PIX é <strong>instantâneo</strong> e sua compra será liberada imediatamente!</p>' ||
            '<div style="background: #F9FAFB; border: 1px solid #E5E7EB; border-radius: 8px; padding: 20px; margin: 25px 0;">' ||
            '<h3 style="margin: 0 0 15px 0; color: #1F2937; font-size: 18px;">📦 Detalhes da sua Compra</h3>' ||
            '<p style="margin: 8px 0; color: #4B5563;"><strong>Produto:</strong> ' || payment_record.product_name || '</p>' ||
            '<p style="margin: 8px 0; color: #4B5563;"><strong>Valor:</strong> <span style="color: #059669; font-size: 20px; font-weight: bold;">R$ ' || 
            REPLACE(TO_CHAR(payment_record.amount / 100.0, 'FM999999990.00'), '.', ',') || '</span></p>' ||
            '<p style="margin: 8px 0; color: #6B7280; font-size: 14px;"><strong>ID:</strong> ' || payment_record.bestfy_id || '</p></div>' ||
            '<div style="text-align: center; margin: 30px 0;">' ||
            '<p style="font-size: 18px; font-weight: bold; color: #1F2937; margin-bottom: 20px;">⚡ Finalize seu PIX agora e receba seu produto instantaneamente!</p>' ||
            '<a href="' || payment_record.secure_url || '" style="display: inline-block; background: linear-gradient(135deg, #32BCAD 0%, #14B8A6 100%); color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 18px; box-shadow: 0 4px 6px rgba(20, 184, 166, 0.3);">📱 Pagar com PIX Agora</a></div>' ||
            '<p style="color: #6B7280; font-size: 14px; text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #E5E7EB;">Este e-mail foi enviado porque você iniciou um pagamento PIX. PIX é instantâneo e 100% seguro!</p>' ||
            '</div></div></body></html>',
          'TextBody', 'Olá ' || payment_record.customer_name || ', finalize seu PIX de R$ ' || 
            REPLACE(TO_CHAR(payment_record.amount / 100.0, 'FM999990.00'), '.', ',') || '. Acesse: ' || payment_record.secure_url,
          'Tag', 'auto-pix-recovery',
          'TrackOpens', true,
          'Metadata', jsonb_build_object(
            'transaction_id', payment_record.bestfy_id,
            'customer_name', payment_record.customer_name,
            'amount', payment_record.amount
          )
        )
      ) INTO request_id;
      
      -- Mark email as sent
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
  
  RAISE NOTICE '[AUTO-RECOVERY] Completed: % emails sent, % errors', email_count, error_count;
  
  RETURN jsonb_build_object(
    'success', true,
    'emails_sent', email_count,
    'errors', error_count,
    'timestamp', NOW()
  );
END;
$$;

-- Schedule cron job to run every minute
SELECT cron.schedule(
  'send-recovery-emails',
  '* * * * *',
  $$SELECT send_pending_recovery_emails();$$
);

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION send_pending_recovery_emails() TO postgres;

-- Log activation
DO $$
BEGIN
  RAISE NOTICE '✅ Recovery email system activated! Cron will run every minute.';
END $$;