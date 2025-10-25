-- ===================================================================
-- 🕐 ALTERAR EXPIRAÇÃO DE CHECKOUTS PARA 24 HORAS
-- ===================================================================
-- Atualmente está em 15 minutos
-- Vamos alterar para 24 horas
-- ===================================================================

-- PASSO 1: Ver configuração atual
SELECT '🔍 VERIFICANDO CONFIGURAÇÃO ATUAL...' as status;

SELECT 
    column_name,
    column_default,
    data_type
FROM information_schema.columns
WHERE table_name = 'checkout_links'
AND column_name = 'expires_at';

-- ===================================================================
-- PASSO 2: ALTERAR DEFAULT DA COLUNA expires_at
-- ===================================================================

SELECT '🔧 ALTERANDO DEFAULT PARA 24 HORAS...' as status;

-- Alterar default para 24 horas
ALTER TABLE checkout_links 
ALTER COLUMN expires_at SET DEFAULT (NOW() + INTERVAL '24 hours');

SELECT '✅ Default alterado para 24 horas!' as status;

-- ===================================================================
-- PASSO 3: ATUALIZAR CHECKOUTS EXISTENTES (OPCIONAL)
-- ===================================================================

SELECT '🔄 ATUALIZANDO CHECKOUTS PENDENTES...' as status;

-- Atualizar apenas checkouts que ainda estão pendentes
-- e que ainda não expiraram
UPDATE checkout_links cl
SET expires_at = NOW() + INTERVAL '24 hours'
FROM payments p
WHERE cl.payment_id = p.id
AND p.status = 'waiting_payment'
AND cl.expires_at > NOW()
AND cl.expires_at < (NOW() + INTERVAL '23 hours');
-- Este último filtro pega apenas os que têm menos de 23h
-- para não resetar checkouts que já foram estendidos

SELECT '✅ Checkouts pendentes atualizados!' as status;

-- ===================================================================
-- PASSO 4: ATUALIZAR FUNÇÃO generate_checkout_links_for_pending_payments
-- ===================================================================

SELECT '🔧 ATUALIZANDO FUNÇÃO DE GERAÇÃO...' as status;

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
        NOW() + INTERVAL '24 hours'  -- ✅ 24 HORAS
      );
      
      v_created_count := v_created_count + 1;
      RAISE NOTICE '✅ Checkout criado: % para payment % (expira em 24h)', v_new_slug, v_payment.bestfy_id;
      
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      RAISE WARNING '❌ Erro ao criar checkout para payment %: %', v_payment.id, SQLERRM;
    END;
  END LOOP;
  
  RETURN jsonb_build_object(
    'created', v_created_count,
    'errors', v_errors
  );
END;
$$;

SELECT '✅ Função atualizada!' as status;

-- ===================================================================
-- PASSO 5: VERIFICAÇÃO FINAL
-- ===================================================================

SELECT '📊 VERIFICAÇÃO FINAL' as status;

-- Ver configuração atual
SELECT 
    '✅ CONFIGURAÇÃO ATUALIZADA' as tipo,
    column_name,
    column_default as novo_default,
    'Deve ser: (now() + ''24:00:00''::interval)' as esperado
FROM information_schema.columns
WHERE table_name = 'checkout_links'
AND column_name = 'expires_at';

-- Ver checkouts e suas expirações
SELECT 
    '📋 CHECKOUTS ATUAIS' as tipo,
    cl.checkout_slug,
    cl.payment_status,
    cl.created_at,
    cl.expires_at,
    ROUND(EXTRACT(EPOCH FROM (cl.expires_at - cl.created_at)) / 3600, 2) as horas_ate_expiracao,
    CASE 
        WHEN cl.expires_at > NOW() THEN '✅ Válido'
        ELSE '❌ Expirado'
    END as status
FROM checkout_links cl
ORDER BY cl.created_at DESC
LIMIT 10;

-- Estatísticas
SELECT 
    '📊 ESTATÍSTICAS' as tipo,
    COUNT(*) as total_checkouts,
    COUNT(*) FILTER (WHERE expires_at > NOW()) as validos,
    COUNT(*) FILTER (WHERE expires_at <= NOW()) as expirados,
    AVG(EXTRACT(EPOCH FROM (expires_at - created_at)) / 3600) as media_horas_expiracao
FROM checkout_links;

-- ===================================================================
-- ✅ PRONTO!
-- ===================================================================
-- MUDANÇAS APLICADAS:
-- 1. ✅ Default da coluna expires_at = 24 horas
-- 2. ✅ Função generate_checkout_links_for_pending_payments atualizada
-- 3. ✅ Checkouts pendentes estendidos para 24h
--
-- RESULTADO:
-- - Novos checkouts criados → Expiram em 24h ✅
-- - Checkouts existentes pendentes → Estendidos para 24h ✅
-- - Função de email de recuperação → Cria com 24h ✅
--
-- PRÓXIMO PASSO:
-- Checkouts enviados por email agora terão 24h para o cliente pagar!
-- ===================================================================

