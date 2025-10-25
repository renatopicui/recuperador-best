-- ===================================================================
-- 🔄 ROLLBACK - REVERTER MUDANÇAS DE EXPIRAÇÃO
-- ===================================================================
-- Este script desfaz as mudanças do ALTERAR-EXPIRACAO-24H.sql
-- e volta para o estado anterior (15 minutos)
-- ===================================================================

-- PASSO 1: Reverter default da coluna
SELECT '🔄 REVERTENDO DEFAULT PARA 15 MINUTOS...' as status;

ALTER TABLE checkout_links 
ALTER COLUMN expires_at SET DEFAULT (NOW() + INTERVAL '15 minutes');

SELECT '✅ Default revertido para 15 minutos!' as status;

-- ===================================================================
-- PASSO 2: BUSCAR FUNÇÃO ORIGINAL NAS MIGRAÇÕES
-- ===================================================================

-- A função original está em:
-- supabase/migrations/20251006035615_update_checkout_expiration_to_15_minutes.sql

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
  v_original_amount NUMERIC;
  v_discount_amount NUMERIC;
  v_final_amount NUMERIC;
BEGIN
  FOR v_payment IN 
    SELECT 
      p.id,
      p.user_id,
      p.bestfy_id,
      p.amount,
      p.customer_name,
      p.customer_email,
      p.customer_document,
      p.customer_address,
      p.product_name
    FROM payments p
    LEFT JOIN checkout_links cl ON cl.payment_id = p.id
    WHERE p.status = 'waiting_payment'
      AND cl.id IS NULL
      AND p.created_at < (NOW() - INTERVAL '1 hour')
    ORDER BY p.created_at
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
        v_payment.amount,
        v_payment.amount,
        20.00,
        v_discount_amount,
        v_final_amount,
        v_payment.bestfy_id,
        NOW() + INTERVAL '15 minutes'  -- ✅ VOLTOU PARA 15 MINUTOS
      );
      
      v_created_count := v_created_count + 1;
      RAISE NOTICE '✅ Checkout link created: % for payment % with 20%% discount (expires in 15 minutes)', v_new_slug, v_payment.bestfy_id;
      
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      RAISE WARNING '❌ Error creating checkout for payment %: %', v_payment.id, SQLERRM;
    END;
  END LOOP;
  
  RETURN jsonb_build_object(
    'created', v_created_count,
    'errors', v_errors
  );
END;
$$;

SELECT '✅ Função revertida para 15 minutos!' as status;

-- ===================================================================
-- VERIFICAÇÃO
-- ===================================================================

SELECT 
    '✅ ROLLBACK COMPLETO' as tipo,
    column_default as novo_default
FROM information_schema.columns
WHERE table_name = 'checkout_links'
AND column_name = 'expires_at';

-- ===================================================================
-- ✅ PRONTO!
-- ===================================================================
-- Sistema voltou ao estado anterior (15 minutos)
-- ===================================================================

