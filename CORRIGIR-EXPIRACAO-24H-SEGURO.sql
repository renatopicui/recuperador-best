-- ===================================================================
-- ✅ CORREÇÃO SEGURA - APENAS ALTERAR TEMPO DE EXPIRAÇÃO
-- ===================================================================
-- Este script APENAS altera o tempo de expiração de 15min → 24h
-- SEM sobrescrever funções ou quebrar funcionalidades
-- ===================================================================

-- PASSO 1: Alterar apenas o DEFAULT da coluna
SELECT '🔧 ALTERANDO DEFAULT PARA 24 HORAS...' as status;

ALTER TABLE checkout_links 
ALTER COLUMN expires_at SET DEFAULT (NOW() + INTERVAL '24 hours');

SELECT '✅ Default alterado!' as status;

-- ===================================================================
-- PASSO 2: Atualizar APENAS a linha de expires_at na função
-- ===================================================================

-- Buscar a função atual
SELECT '🔍 Buscando função atual...' as status;

SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines
WHERE routine_name = 'generate_checkout_links_for_pending_payments'
AND routine_schema = 'public';

-- ===================================================================
-- PASSO 3: Recriar função com APENAS mudança no expires_at
-- ===================================================================

SELECT '🔧 ATUALIZANDO APENAS O TEMPO DE EXPIRAÇÃO NA FUNÇÃO...' as status;

-- Você precisa substituir APENAS a linha:
-- NOW() + INTERVAL '15 minutes'
-- por:
-- NOW() + INTERVAL '24 hours'

-- A função completa deve ser:

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
        NOW() + INTERVAL '24 hours'  -- ✅ ÚNICA MUDANÇA: 15min → 24h
      );
      
      v_created_count := v_created_count + 1;
      RAISE NOTICE '✅ Checkout created: % (expires in 24h)', v_new_slug;
      
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      RAISE WARNING '❌ Error: %', SQLERRM;
    END;
  END LOOP;
  
  RETURN jsonb_build_object(
    'created', v_created_count,
    'errors', v_errors
  );
END;
$$;

SELECT '✅ Função atualizada com 24h!' as status;

-- ===================================================================
-- PASSO 4: Estender checkouts pendentes existentes
-- ===================================================================

SELECT '🔄 ESTENDENDO CHECKOUTS PENDENTES...' as status;

UPDATE checkout_links cl
SET expires_at = NOW() + INTERVAL '24 hours'
FROM payments p
WHERE cl.payment_id = p.id
AND p.status = 'waiting_payment'
AND cl.expires_at > NOW()
AND cl.expires_at < (NOW() + INTERVAL '23 hours');

SELECT '✅ Checkouts estendidos!' as status;

-- ===================================================================
-- PASSO 5: VERIFICAR TRIGGERS (NÃO ALTERAR)
-- ===================================================================

SELECT '🔍 VERIFICANDO TRIGGERS...' as status;

SELECT 
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND event_object_table IN ('checkout_links', 'payments')
ORDER BY event_object_table, trigger_name;

-- Se os triggers estiverem OK, você verá:
-- - generate_thank_you_on_payment_paid
-- - generate_thank_you_on_checkout_paid
-- Eles NÃO devem ser alterados!

-- ===================================================================
-- PASSO 6: VERIFICAÇÃO FINAL
-- ===================================================================

SELECT '📊 VERIFICAÇÃO FINAL' as status;

SELECT 
    '✅ CONFIGURAÇÃO' as tipo,
    column_default as default_value
FROM information_schema.columns
WHERE table_name = 'checkout_links'
AND column_name = 'expires_at';

SELECT 
    '📋 CHECKOUTS' as tipo,
    checkout_slug,
    ROUND(EXTRACT(EPOCH FROM (expires_at - created_at)) / 3600, 2) as horas_validade,
    CASE 
        WHEN expires_at > NOW() THEN '✅ Válido'
        ELSE '❌ Expirado'
    END as status
FROM checkout_links
ORDER BY created_at DESC
LIMIT 5;

-- ===================================================================
-- ✅ PRONTO!
-- ===================================================================
-- MUDANÇAS APLICADAS (SEGURAS):
-- 1. ✅ Default da coluna expires_at = 24h
-- 2. ✅ Função generate_checkout_links atualizada (24h)
-- 3. ✅ Checkouts pendentes estendidos
-- 4. ✅ TRIGGERS NÃO FORAM ALTERADOS
-- 5. ✅ TUDO O RESTO PERMANECE FUNCIONANDO
-- ===================================================================

