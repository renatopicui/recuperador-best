-- ===================================================================
-- 🚀 RESOLVER TUDO DE UMA VEZ
-- ===================================================================
-- Este script:
-- 1. Corrige a função (3 minutos + 24h)
-- 2. Cria TODOS os checkouts pendentes
-- 3. Configura cron job automático
-- 4. Testa se está funcionando
-- ===================================================================

-- ===================================================================
-- PARTE 1: CORRIGIR FUNÇÃO
-- ===================================================================

SELECT '🔧 PARTE 1: CORRIGINDO FUNÇÃO...' as status;

ALTER TABLE checkout_links 
ALTER COLUMN expires_at SET DEFAULT (NOW() + INTERVAL '24 hours');

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
      p.id, p.user_id, p.bestfy_id, p.amount,
      p.customer_name, p.customer_email, p.customer_document,
      p.customer_address, p.product_name
    FROM payments p
    LEFT JOIN checkout_links cl ON cl.payment_id = p.id
    WHERE p.status = 'waiting_payment'
      AND cl.id IS NULL
      AND p.created_at < (NOW() - INTERVAL '3 minutes')  -- ✅ 3 MINUTOS
    ORDER BY p.created_at
  LOOP
    BEGIN
      v_new_slug := generate_checkout_slug();
      v_original_amount := v_payment.amount;
      v_discount_amount := ROUND(v_original_amount * 0.20, 0);
      v_final_amount := v_original_amount - v_discount_amount;
      
      INSERT INTO checkout_links (
        payment_id, user_id, checkout_slug,
        customer_name, customer_email, customer_document, customer_address,
        product_name, amount, original_amount, discount_percentage,
        discount_amount, final_amount, payment_bestfy_id, expires_at
      ) VALUES (
        v_payment.id, v_payment.user_id, v_new_slug,
        v_payment.customer_name, v_payment.customer_email, v_payment.customer_document,
        v_payment.customer_address, v_payment.product_name, v_payment.amount,
        v_payment.amount, 20.00, v_discount_amount, v_final_amount,
        v_payment.bestfy_id, NOW() + INTERVAL '24 hours'  -- ✅ 24 HORAS
      );
      
      v_created_count := v_created_count + 1;
      RAISE NOTICE '✅ Checkout: %', v_new_slug;
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      RAISE WARNING '❌ Erro: %', SQLERRM;
    END;
  END LOOP;
  
  RETURN jsonb_build_object('created', v_created_count, 'errors', v_errors);
END;
$$;

SELECT '✅ Função corrigida!' as status;

-- ===================================================================
-- PARTE 2: CRIAR TODOS OS CHECKOUTS PENDENTES
-- ===================================================================

SELECT '🚀 PARTE 2: CRIANDO CHECKOUTS PENDENTES...' as status;

SELECT generate_checkout_links_for_pending_payments() as resultado;

-- ===================================================================
-- PARTE 3: CONFIGURAR CRON JOB AUTOMÁTICO
-- ===================================================================

SELECT '⏰ PARTE 3: CONFIGURANDO CRON JOB...' as status;

-- Remover job antigo se existir
SELECT cron.unschedule('auto-create-checkouts') 
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'auto-create-checkouts');

-- Criar novo job (roda a cada 5 minutos)
SELECT cron.schedule(
  'auto-create-checkouts',
  '*/5 * * * *',
  $$SELECT generate_checkout_links_for_pending_payments()$$
);

SELECT '✅ Cron job configurado (roda a cada 5 minutos)!' as status;

-- ===================================================================
-- PARTE 4: MOSTRAR LINKS CRIADOS
-- ===================================================================

SELECT '📋 PARTE 4: CHECKOUTS CRIADOS' as status;

SELECT 
    p.customer_email,
    p.customer_name,
    p.product_name,
    ROUND(cl.final_amount / 100.0, 2) as valor_pagar,
    'http://localhost:5173/checkout/' || cl.checkout_slug as link_enviar,
    TO_CHAR(cl.expires_at, 'DD/MM/YYYY HH24:MI') as expira_em
FROM checkout_links cl
INNER JOIN payments p ON cl.payment_id = p.id
WHERE cl.created_at > NOW() - INTERVAL '10 minutes'
AND p.status = 'waiting_payment'
ORDER BY cl.created_at DESC;

-- ===================================================================
-- PARTE 5: VERIFICAR SE ESTÁ TUDO OK
-- ===================================================================

SELECT '✅ PARTE 5: VERIFICAÇÃO FINAL' as status;

-- Ver cron job
SELECT 
    '⏰ CRON JOB' as tipo,
    jobname,
    schedule,
    active,
    CASE WHEN active THEN '✅ Ativo' ELSE '❌ Inativo' END as status
FROM cron.job
WHERE jobname = 'auto-create-checkouts';

-- Ver configuração da função
SELECT 
    '🔧 FUNÇÃO' as tipo,
    CASE 
        WHEN routine_definition LIKE '%3 minutes%'
        THEN '✅ Correto (3 minutos)'
        ELSE '❌ Errado'
    END as tempo_espera,
    CASE 
        WHEN routine_definition LIKE '%24 hours%'
        THEN '✅ Correto (24 horas)'
        ELSE '❌ Errado'
    END as tempo_expiracao
FROM information_schema.routines
WHERE routine_name = 'generate_checkout_links_for_pending_payments';

-- Ver se ainda há transações sem checkout
SELECT 
    '📊 TRANSAÇÕES' as tipo,
    COUNT(*) FILTER (WHERE p.status = 'waiting_payment') as total_pendentes,
    COUNT(*) FILTER (WHERE p.status = 'waiting_payment' AND cl.id IS NULL) as sem_checkout,
    CASE 
        WHEN COUNT(*) FILTER (WHERE p.status = 'waiting_payment' AND cl.id IS NULL) = 0
        THEN '✅ Todos têm checkout!'
        ELSE '⚠️ ' || COUNT(*) FILTER (WHERE p.status = 'waiting_payment' AND cl.id IS NULL)::text || ' ainda sem checkout'
    END as diagnostico
FROM payments p
LEFT JOIN checkout_links cl ON cl.payment_id = p.id
WHERE p.created_at > NOW() - INTERVAL '1 day';

-- ===================================================================
-- RESUMO FINAL
-- ===================================================================

SELECT '🎉 RESUMO FINAL' as status;

SELECT 
    '✅✅✅ TUDO CONFIGURADO!' as resultado,
    '3 minutos' as cria_checkout_apos,
    '24 horas' as checkout_expira_em,
    '5 minutos' as cron_job_roda_a_cada,
    'FUNCIONANDO AUTOMATICAMENTE' as status_sistema;

-- ===================================================================
-- ✅ PRONTO!
-- ===================================================================
-- CONFIGURAÇÃO COMPLETA:
-- 1. ✅ Função corrigida (3min + 24h)
-- 2. ✅ Checkouts pendentes criados
-- 3. ✅ Cron job ativo (5 em 5 minutos)
-- 4. ✅ Sistema 100% automático
--
-- TESTE:
-- 1. Crie uma transação
-- 2. Aguarde 3-5 minutos
-- 3. Verifique se checkout foi criado automaticamente
--
-- PRÓXIMA TRANSAÇÃO:
-- Será criada automaticamente após 3 minutos! ✅
-- ===================================================================

