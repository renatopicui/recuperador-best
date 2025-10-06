/*
  # Adicionar desconto de 20% e temporizador ao checkout

  1. Alterações na tabela checkout_links
    - Adicionar discount_percentage (sempre 20%)
    - Adicionar original_amount (valor original)
    - Adicionar discount_amount (valor do desconto)
    - Adicionar final_amount (valor final com desconto)
    - Adicionar customer_address (endereço do cliente)
    - Adicionar user_id (dono do checkout)
    - Modificar expires_at para 5 minutos

  2. Função atualizada
    - get_checkout_by_slug retorna todas as informações necessárias
    - generate_checkout_links_for_pending_payments calcula desconto de 20%
*/

-- Adicionar colunas faltantes
ALTER TABLE checkout_links 
ADD COLUMN IF NOT EXISTS discount_percentage DECIMAL DEFAULT 20,
ADD COLUMN IF NOT EXISTS original_amount DECIMAL,
ADD COLUMN IF NOT EXISTS discount_amount DECIMAL,
ADD COLUMN IF NOT EXISTS final_amount DECIMAL,
ADD COLUMN IF NOT EXISTS customer_address JSONB,
ADD COLUMN IF NOT EXISTS user_id UUID,
ADD COLUMN IF NOT EXISTS payment_bestfy_id TEXT,
ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'waiting_payment',
ADD COLUMN IF NOT EXISTS pix_qrcode TEXT,
ADD COLUMN IF NOT EXISTS pix_expires_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS pix_generated_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

-- Atualizar função get_checkout_by_slug para retornar todos os campos
DROP FUNCTION IF EXISTS get_checkout_by_slug(TEXT);

CREATE OR REPLACE FUNCTION get_checkout_by_slug(slug TEXT)
RETURNS TABLE(
  id UUID,
  checkout_slug TEXT,
  payment_id UUID,
  user_id UUID,
  customer_email TEXT,
  customer_name TEXT,
  customer_document TEXT,
  customer_address JSONB,
  amount DECIMAL,
  original_amount DECIMAL,
  discount_percentage DECIMAL,
  discount_amount DECIMAL,
  final_amount DECIMAL,
  product_name TEXT,
  status TEXT,
  pix_qrcode TEXT,
  pix_expires_at TIMESTAMPTZ,
  pix_generated_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  access_count INTEGER,
  payment_bestfy_id TEXT,
  payment_status TEXT
) AS $$
BEGIN
  -- Incrementar contador de acesso
  UPDATE checkout_links cl
  SET 
    access_count = cl.access_count + 1,
    last_accessed_at = NOW()
  WHERE cl.checkout_slug = slug;

  RETURN QUERY
  SELECT 
    cl.id,
    cl.checkout_slug,
    cl.payment_id,
    cl.user_id,
    cl.customer_email,
    cl.customer_name,
    cl.customer_document,
    cl.customer_address,
    cl.amount,
    cl.original_amount,
    cl.discount_percentage,
    cl.discount_amount,
    cl.final_amount,
    cl.product_name,
    cl.status,
    cl.pix_qrcode,
    cl.pix_expires_at,
    cl.pix_generated_at,
    cl.expires_at,
    cl.access_count,
    cl.payment_bestfy_id,
    cl.payment_status
  FROM checkout_links cl
  WHERE cl.checkout_slug = slug
    AND cl.expires_at > NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Atualizar função de geração para calcular desconto de 20% e expirar em 5 minutos
DROP FUNCTION IF EXISTS generate_checkout_links_for_pending_payments();

CREATE OR REPLACE FUNCTION generate_checkout_links_for_pending_payments()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_payment RECORD;
  v_new_slug TEXT;
  v_created_count INTEGER := 0;
  v_errors INTEGER := 0;
  v_error_message TEXT;
  v_original_amount DECIMAL;
  v_discount_amount DECIMAL;
  v_final_amount DECIMAL;
BEGIN
  FOR v_payment IN
    SELECT 
      p.id,
      p.user_id,
      p.bestfy_id,
      p.customer_name,
      p.customer_email,
      p.customer_document,
      p.customer_address,
      p.product_name,
      p.amount
    FROM payments p
    WHERE p.status = 'waiting_payment'
      AND p.payment_method = 'pix'
      AND p.created_at < (NOW() - INTERVAL '3 minutes')
      AND NOT EXISTS (
        SELECT 1 
        FROM checkout_links cl 
        WHERE cl.payment_id = p.id
      )
  LOOP
    BEGIN
      v_new_slug := generate_checkout_slug();
      
      -- Calcular desconto de 20%
      v_original_amount := v_payment.amount;
      v_discount_amount := ROUND(v_original_amount * 0.20, 0);
      v_final_amount := v_original_amount - v_discount_amount;
      
      INSERT INTO checkout_links (
        payment_id,
        user_id,
        checkout_slug,
        customer_name,
        customer_email,
        customer_document,
        customer_address,
        product_name,
        amount,
        original_amount,
        discount_percentage,
        discount_amount,
        final_amount,
        payment_bestfy_id,
        expires_at
      ) VALUES (
        v_payment.id,
        v_payment.user_id,
        v_new_slug,
        v_payment.customer_name,
        v_payment.customer_email,
        v_payment.customer_document,
        v_payment.customer_address,
        v_payment.product_name,
        v_original_amount,
        v_original_amount,
        20,
        v_discount_amount,
        v_final_amount,
        v_payment.bestfy_id,
        NOW() + INTERVAL '5 minutes'
      );
      
      v_created_count := v_created_count + 1;
      RAISE NOTICE '✅ Checkout link created: % for payment % with 20%% discount', v_new_slug, v_payment.bestfy_id;
      
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      v_error_message := SQLERRM;
      RAISE WARNING '❌ Error creating checkout for payment %: %', v_payment.bestfy_id, v_error_message;
    END;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true,
    'checkout_links_created', v_created_count,
    'errors', v_errors,
    'timestamp', NOW()
  );
END;
$$;