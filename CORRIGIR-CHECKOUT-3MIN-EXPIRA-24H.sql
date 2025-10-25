-- ===================================================================
-- ✅ CORREÇÃO DEFINITIVA
-- ===================================================================
-- Cria checkout após 3 MINUTOS (como era antes)
-- Expira em 24 HORAS (como você pediu)
-- ===================================================================

-- PASSO 1: Alterar default da coluna para 24 horas
SELECT '🔧 CONFIGURANDO EXPIRAÇÃO DE 24 HORAS...' as status;

ALTER TABLE checkout_links 
ALTER COLUMN expires_at SET DEFAULT (NOW() + INTERVAL '24 hours');

SELECT '✅ Expiração configurada para 24h!' as status;

-- ===================================================================
-- PASSO 2: Recriar função com LÓGICA CORRETA
-- ===================================================================

SELECT '🔧 CORRIGINDO FUNÇÃO...' as status;

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
      AND p.created_at < (NOW() - INTERVAL '3 minutes')  -- ✅ 3 MINUTOS!
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
        NOW() + INTERVAL '24 hours'  -- ✅ EXPIRA EM 24 HORAS!
      );
      
      v_created_count := v_created_count + 1;
      RAISE NOTICE '✅ Checkout criado: % (expira em 24h)', v_new_slug;
      
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      RAISE WARNING '❌ Erro ao criar checkout: %', SQLERRM;
    END;
  END LOOP;
  
  RETURN jsonb_build_object(
    'created', v_created_count,
    'errors', v_errors
  );
END;
$$;

SELECT '✅ Função corrigida!' as status;

-- ===================================================================
-- PASSO 3: TESTAR AGORA MANUALMENTE
-- ===================================================================

SELECT '🧪 TESTANDO FUNÇÃO...' as status;

-- Buscar pagamentos que atendem critérios
SELECT 
    '📋 PAGAMENTOS QUE DEVEM TER CHECKOUT' as tipo,
    p.id,
    p.customer_email,
    p.amount,
    p.created_at,
    EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 60 as minutos_desde_criacao,
    CASE 
        WHEN cl.id IS NULL THEN '❌ SEM CHECKOUT'
        ELSE '✅ JÁ TEM CHECKOUT'
    END as status_checkout
FROM payments p
LEFT JOIN checkout_links cl ON cl.payment_id = p.id
WHERE p.status = 'waiting_payment'
AND p.created_at < (NOW() - INTERVAL '3 minutes')
ORDER BY p.created_at DESC
LIMIT 10;

-- Executar função manualmente
SELECT '🚀 EXECUTANDO FUNÇÃO...' as status;

SELECT generate_checkout_links_for_pending_payments() as resultado;

-- Verificar se criou
SELECT 
    '✅ CHECKOUTS CRIADOS' as tipo,
    cl.checkout_slug,
    cl.customer_email,
    cl.created_at,
    cl.expires_at,
    ROUND(EXTRACT(EPOCH FROM (cl.expires_at - cl.created_at)) / 3600, 2) as horas_expiracao,
    'http://localhost:5173/checkout/' || cl.checkout_slug as link
FROM checkout_links cl
WHERE cl.created_at > NOW() - INTERVAL '5 minutes'
ORDER BY cl.created_at DESC;

-- ===================================================================
-- PASSO 4: RESUMO DO QUE FOI CORRIGIDO
-- ===================================================================

SELECT '📊 RESUMO' as status;

SELECT 
    '✅ CONFIGURAÇÃO FINAL' as tipo,
    '3 minutos' as cria_checkout_apos,
    '24 horas' as checkout_expira_em,
    'CORRIGIDO ✅' as status;

-- ===================================================================
-- ✅ PRONTO!
-- ===================================================================
-- LÓGICA CORRIGIDA:
-- 1. ✅ Transação criada
-- 2. ✅ Após 3 MINUTOS → Cria checkout (voltou ao normal!)
-- 3. ✅ Checkout expira em 24 HORAS (como você pediu!)
-- 4. ✅ Cliente tem 24h para pagar
--
-- O QUE ESTAVA ERRADO:
-- - Script anterior colocou 1 HORA para criar checkout
-- - Deveria ser 3 MINUTOS
--
-- O QUE FOI CONSERTADO:
-- - Voltou para 3 MINUTOS
-- - Mas manteve expiração de 24 HORAS
--
-- TESTE:
-- 1. Crie uma transação de teste
-- 2. Aguarde 3 minutos
-- 3. Execute: SELECT generate_checkout_links_for_pending_payments();
-- 4. Verifique se checkout foi criado
-- ===================================================================

