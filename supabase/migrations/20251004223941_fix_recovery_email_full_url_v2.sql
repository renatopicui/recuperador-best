/*
  # Corrigir Email de Recuperação - Usar URL Completa

  1. Objetivo
    - Corrigir o link do email para usar URL completa em vez de caminho relativo
    - Links relativos (/checkout/slug) não funcionam em emails
    - Usar URL completa (https://dominio.com/checkout/slug)

  2. Mudanças
    - Criar tabela de configurações do sistema
    - Armazenar APP_URL para construir links completos
    - Atualizar função de recuperação para usar URL completa

  3. Segurança
    - RLS habilitado na tabela de configurações
    - Apenas admins podem alterar configurações
*/

-- Create system settings table
CREATE TABLE IF NOT EXISTS system_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text UNIQUE NOT NULL,
  value text NOT NULL,
  description text,
  created_at timestamptz DEFAULT NOW(),
  updated_at timestamptz DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Authenticated users can read settings" ON system_settings;

-- Only authenticated users can read settings
CREATE POLICY "Authenticated users can read settings"
  ON system_settings
  FOR SELECT
  TO authenticated
  USING (true);

-- Insert default APP_URL (user should update this)
INSERT INTO system_settings (key, value, description)
VALUES ('APP_URL', 'https://seu-dominio.com', 'URL base da aplicação para construir links de checkout')
ON CONFLICT (key) DO NOTHING;

-- Drop existing function
DROP FUNCTION IF EXISTS send_pending_recovery_emails();

-- Create improved function with full URL
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
  checkout_url text;
  app_base_url text;
BEGIN
  RAISE NOTICE '[AUTO-RECOVERY] Starting recovery email check at %', NOW();
  
  -- Get APP_URL from settings
  SELECT value INTO app_base_url 
  FROM system_settings 
  WHERE key = 'APP_URL' 
  LIMIT 1;
  
  -- Default fallback if not configured
  IF app_base_url IS NULL OR app_base_url = '' THEN
    app_base_url := 'https://seu-dominio.com';
  END IF;
  
  -- Remove trailing slash if present
  app_base_url := RTRIM(app_base_url, '/');
  
  RAISE NOTICE '[AUTO-RECOVERY] Using base URL: %', app_base_url;
  
  -- Loop through eligible payments that have checkout links
  FOR payment_record IN
    SELECT 
      p.id,
      p.bestfy_id,
      p.customer_email,
      p.customer_name,
      p.product_name,
      p.amount,
      cl.checkout_slug
    FROM payments p
    INNER JOIN checkout_links cl ON cl.payment_id = p.id
    WHERE p.status = 'waiting_payment'
      AND p.payment_method = 'pix'
      AND p.recovery_email_sent_at IS NULL
      AND p.created_at < (NOW() - INTERVAL '3 minutes')
      AND cl.checkout_slug IS NOT NULL
    ORDER BY p.created_at ASC
    LIMIT 5
  LOOP
    BEGIN
      -- Build full checkout URL
      checkout_url := app_base_url || '/checkout/' || payment_record.checkout_slug;
      
      RAISE NOTICE '[AUTO-RECOVERY] Sending email to: % (%) - Checkout: %', 
        payment_record.customer_email, 
        payment_record.bestfy_id,
        checkout_url;
      
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
            '<a href="' || checkout_url || '" style="display: inline-block; background: linear-gradient(135deg, #32BCAD 0%, #14B8A6 100%); color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 18px; box-shadow: 0 4px 6px rgba(20, 184, 166, 0.3);">📱 Pagar com PIX Agora</a></div>' ||
            '<p style="color: #6B7280; font-size: 14px; text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #E5E7EB;">Este e-mail foi enviado porque você iniciou um pagamento PIX. PIX é instantâneo e 100% seguro!</p>' ||
            '</div></div></body></html>',
          'TextBody', 'Olá ' || payment_record.customer_name || ', finalize seu PIX de R$ ' || 
            REPLACE(TO_CHAR(payment_record.amount / 100.0, 'FM999990.00'), '.', ',') || '. Acesse: ' || checkout_url,
          'Tag', 'auto-pix-recovery',
          'TrackOpens', true,
          'Metadata', jsonb_build_object(
            'transaction_id', payment_record.bestfy_id,
            'customer_name', payment_record.customer_name,
            'amount', payment_record.amount,
            'checkout_slug', payment_record.checkout_slug,
            'checkout_url', checkout_url
          )
        )
      ) INTO request_id;
      
      -- Mark email as sent
      UPDATE payments
      SET recovery_email_sent_at = NOW()
      WHERE id = payment_record.id;
      
      email_count := email_count + 1;
      
      RAISE NOTICE '[AUTO-RECOVERY] ✅ Email queued for % (request_id: %) - Full URL: %', 
        payment_record.customer_email, 
        request_id,
        checkout_url;
      
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
    'base_url', app_base_url,
    'timestamp', NOW()
  );
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION send_pending_recovery_emails() TO postgres;