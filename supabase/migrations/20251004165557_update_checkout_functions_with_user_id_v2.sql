/*
  # Atualizar funções de checkout para incluir user_id

  Esta migração atualiza as funções relacionadas aos checkouts para incluir
  o user_id, permitindo identificar qual API key usar ao criar transações.

  ## 1. Mudanças
  - Atualiza `generate_checkout_links_for_pending_payments()` para incluir user_id
  - Remove e recria `get_checkout_by_slug()` para retornar user_id
  
  ## 2. Notas
  - O user_id é necessário para buscar a API key correta ao criar transações PIX
  - Mantém compatibilidade com dados existentes (user_id pode ser null temporariamente)
*/

-- Atualiza função para criar checkout links com user_id
CREATE OR REPLACE FUNCTION generate_checkout_links_for_pending_payments()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_payment RECORD;
  v_new_slug text;
  v_created_count integer := 0;
  v_errors integer := 0;
  v_error_message text;
BEGIN
  -- Loop through eligible payments (pending > 3 min, no checkout link yet)
  FOR v_payment IN
    SELECT 
      p.id,
      p.bestfy_id,
      p.user_id,
      p.customer_name,
      p.customer_email,
      p.customer_document,
      p.product_name,
      p.amount,
      p.items,
      p.metadata
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
      -- Generate unique slug
      v_new_slug := generate_checkout_slug();
      
      -- Create checkout link with user_id
      INSERT INTO checkout_links (
        payment_id,
        user_id,
        checkout_slug,
        customer_name,
        customer_email,
        customer_document,
        product_name,
        amount,
        items,
        metadata
      ) VALUES (
        v_payment.id,
        v_payment.user_id,
        v_new_slug,
        v_payment.customer_name,
        v_payment.customer_email,
        v_payment.customer_document,
        v_payment.product_name,
        v_payment.amount,
        v_payment.items,
        v_payment.metadata
      );
      
      v_created_count := v_created_count + 1;
      
      RAISE NOTICE '✅ Checkout link created: % for payment %', v_new_slug, v_payment.bestfy_id;
      
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      v_error_message := SQLERRM;
      RAISE WARNING '❌ Error creating checkout for payment %: %', v_payment.bestfy_id, v_error_message;
    END;
  END LOOP;
  
  -- Return summary
  RETURN jsonb_build_object(
    'success', true,
    'checkout_links_created', v_created_count,
    'errors', v_errors,
    'timestamp', NOW()
  );
END;
$$;

-- Remove função antiga
DROP FUNCTION IF EXISTS get_checkout_by_slug(text);

-- Recria função para buscar checkout por slug incluindo user_id
CREATE OR REPLACE FUNCTION get_checkout_by_slug(slug text)
RETURNS TABLE (
  checkout_slug text,
  user_id uuid,
  customer_name text,
  customer_email text,
  customer_document text,
  product_name text,
  amount numeric,
  items jsonb,
  metadata jsonb,
  expires_at timestamptz,
  payment_status text,
  payment_bestfy_id text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Increment access count
  PERFORM increment_checkout_access(slug);
  
  -- Return checkout details with payment status and user_id
  RETURN QUERY
  SELECT 
    cl.checkout_slug,
    cl.user_id,
    cl.customer_name,
    cl.customer_email,
    cl.customer_document,
    cl.product_name,
    cl.amount,
    cl.items,
    cl.metadata,
    cl.expires_at,
    p.status as payment_status,
    p.bestfy_id as payment_bestfy_id
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.checkout_slug = slug
    AND cl.expires_at > NOW();
END;
$$;
