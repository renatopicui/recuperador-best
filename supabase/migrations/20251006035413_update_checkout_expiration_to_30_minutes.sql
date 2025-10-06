/*
  # Atualizar expiração do checkout para 30 minutos
  
  1. Alterações
    - Modificar o default da coluna expires_at na tabela checkout_links de 24 horas para 30 minutos
    - Atualizar a função generate_checkout_links_for_pending_payments para usar 30 minutos
  
  2. Notas
    - Isso afeta apenas novos checkouts criados após esta migração
    - Checkouts existentes mantêm sua data de expiração original
*/

-- Alterar o default da coluna expires_at para 30 minutos
ALTER TABLE checkout_links 
ALTER COLUMN expires_at SET DEFAULT (NOW() + INTERVAL '30 minutes');

-- Recriar função de geração de checkout com expiração de 30 minutos
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
        NOW() + INTERVAL '30 minutes'
      );
      
      v_created_count := v_created_count + 1;
      RAISE NOTICE '✅ Checkout link created: % for payment % with 20%% discount (expires in 30 minutes)', v_new_slug, v_payment.bestfy_id;
      
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