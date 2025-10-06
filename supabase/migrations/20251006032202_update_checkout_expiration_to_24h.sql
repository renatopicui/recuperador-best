/*
  # Atualizar tempo de expiração dos checkout links para 24 horas

  1. Alterações
    - Modificar a função generate_checkout_links_for_pending_payments
    - Alterar expires_at de 5 minutos para 24 horas
    - Manter todas as outras funcionalidades (desconto de 20%, etc)

  2. Motivo
    - Links de checkout devem permanecer válidos por 24 horas
    - Dar mais tempo aos clientes para completarem a compra
*/

-- Atualizar função de geração para expirar em 24 horas
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
        NOW() + INTERVAL '24 hours'
      );
      
      v_created_count := v_created_count + 1;
      RAISE NOTICE '✅ Checkout link created: % for payment % with 20%% discount (expires in 24h)', v_new_slug, v_payment.bestfy_id;
      
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