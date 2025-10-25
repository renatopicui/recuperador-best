-- ===================================================================
-- ⚡ FORÇAR CRIAÇÃO DE TODOS OS CHECKOUTS PENDENTES AGORA
-- ===================================================================
-- Este script cria checkouts para TODAS as transações que precisam
-- ===================================================================

-- PASSO 1: Ver quantas transações estão esperando
SELECT '🔍 PASSO 1: TRANSAÇÕES SEM CHECKOUT' as status;

SELECT 
    '📊 ESTATÍSTICAS' as tipo,
    COUNT(*) as total_pendentes,
    COUNT(*) FILTER (WHERE p.created_at < NOW() - INTERVAL '3 minutes') as ja_passaram_3min,
    COUNT(*) FILTER (WHERE p.created_at < NOW() - INTERVAL '1 minute') as ja_passaram_1min
FROM payments p
LEFT JOIN checkout_links cl ON cl.payment_id = p.id
WHERE p.status = 'waiting_payment'
AND cl.id IS NULL;

-- Lista das transações
SELECT 
    '📋 TRANSAÇÕES QUE PRECISAM DE CHECKOUT' as tipo,
    p.id,
    p.customer_name,
    p.customer_email,
    p.product_name,
    p.amount / 100.0 as valor_reais,
    p.created_at,
    ROUND(EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 60, 1) as minutos_atras,
    CASE 
        WHEN EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 60 >= 3
        THEN '✅ Deve criar AGORA'
        ELSE '⏳ Aguardando'
    END as status
FROM payments p
LEFT JOIN checkout_links cl ON cl.payment_id = p.id
WHERE p.status = 'waiting_payment'
AND cl.id IS NULL
ORDER BY p.created_at DESC;

-- ===================================================================
-- PASSO 2: FORÇAR CRIAÇÃO DE TODOS OS CHECKOUTS
-- ===================================================================

SELECT '🚀 PASSO 2: CRIANDO TODOS OS CHECKOUTS...' as status;

-- Executar função
SELECT generate_checkout_links_for_pending_payments() as resultado;

-- Resultado esperado: {"created": X, "errors": 0}

-- ===================================================================
-- PASSO 3: VERIFICAR O QUE FOI CRIADO
-- ===================================================================

SELECT '✅ PASSO 3: CHECKOUTS CRIADOS AGORA' as status;

SELECT 
    '🔗 CHECKOUTS RECÉM-CRIADOS' as tipo,
    cl.checkout_slug,
    p.customer_name,
    p.customer_email,
    p.product_name,
    cl.amount / 100.0 as valor_original,
    cl.final_amount / 100.0 as valor_com_desconto,
    cl.discount_amount / 100.0 as economia,
    'http://localhost:5173/checkout/' || cl.checkout_slug as link_completo,
    TO_CHAR(cl.expires_at, 'DD/MM/YYYY HH24:MI') as expira_em,
    ROUND(EXTRACT(EPOCH FROM (cl.expires_at - cl.created_at)) / 3600, 2) as horas_validade
FROM checkout_links cl
INNER JOIN payments p ON cl.payment_id = p.id
WHERE cl.created_at > NOW() - INTERVAL '5 minutes'
ORDER BY cl.created_at DESC;

-- ===================================================================
-- PASSO 4: LISTAR TODOS OS LINKS PARA ENVIAR
-- ===================================================================

SELECT '📧 PASSO 4: LINKS PARA ENVIAR AOS CLIENTES' as status;

SELECT 
    p.customer_email as para,
    p.customer_name as nome,
    p.product_name as produto,
    'R$ ' || ROUND(cl.final_amount / 100.0, 2) as valor_pagar,
    'http://localhost:5173/checkout/' || cl.checkout_slug as link_enviar
FROM checkout_links cl
INNER JOIN payments p ON cl.payment_id = p.id
WHERE cl.created_at > NOW() - INTERVAL '5 minutes'
AND p.status = 'waiting_payment'
ORDER BY cl.created_at DESC;

-- ===================================================================
-- PASSO 5: MARCAR COMO EMAIL ENVIADO (OPCIONAL)
-- ===================================================================

-- Se você vai enviar os emails manualmente, marque como enviado:
-- UPDATE payments
-- SET recovery_email_sent_at = NOW()
-- WHERE id IN (
--     SELECT p.id 
--     FROM payments p
--     INNER JOIN checkout_links cl ON cl.payment_id = p.id
--     WHERE cl.created_at > NOW() - INTERVAL '5 minutes'
-- );

-- ===================================================================
-- PASSO 6: DIAGNOSTICAR POR QUE NÃO ESTÁ CRIANDO AUTOMATICAMENTE
-- ===================================================================

SELECT '🔍 PASSO 6: DIAGNÓSTICO DO PROBLEMA' as status;

-- Ver configuração da função
SELECT 
    '⚙️ CONFIGURAÇÃO DA FUNÇÃO' as tipo,
    routine_name,
    CASE 
        WHEN routine_definition LIKE '%3 minutes%'
        THEN '✅ Correto (espera 3 minutos)'
        WHEN routine_definition LIKE '%1 hour%'
        THEN '❌ ERRADO (espera 1 hora) - Execute CORRIGIR-CHECKOUT-3MIN-EXPIRA-24H.sql'
        ELSE '⚠️ Verificar manualmente'
    END as diagnostico
FROM information_schema.routines
WHERE routine_name = 'generate_checkout_links_for_pending_payments'
AND routine_schema = 'public';

-- Ver cron jobs
SELECT 
    '⏰ CRON JOBS' as tipo,
    jobname,
    schedule,
    active,
    CASE 
        WHEN active THEN '✅ Ativo'
        ELSE '❌ Inativo - Cron não vai executar!'
    END as status
FROM cron.job
WHERE jobname LIKE '%checkout%' OR jobname LIKE '%recovery%'
ORDER BY jobname;

-- ===================================================================
-- RESUMO FINAL
-- ===================================================================

SELECT '📊 RESUMO FINAL' as status;

WITH stats AS (
    SELECT 
        COUNT(*) as total_transacoes,
        COUNT(*) FILTER (WHERE p.status = 'waiting_payment') as pendentes,
        COUNT(cl.id) as com_checkout,
        COUNT(*) FILTER (WHERE p.status = 'waiting_payment' AND cl.id IS NULL) as sem_checkout
    FROM payments p
    LEFT JOIN checkout_links cl ON cl.payment_id = p.id
    WHERE p.created_at > NOW() - INTERVAL '1 day'
)
SELECT 
    '🎯 STATUS GERAL' as tipo,
    total_transacoes as total_ultimas_24h,
    pendentes as pendentes,
    com_checkout as com_checkout_criado,
    sem_checkout as ainda_sem_checkout,
    CASE 
        WHEN sem_checkout = 0 
        THEN '✅ Todos os checkouts foram criados!'
        ELSE '⚠️ Ainda há ' || sem_checkout || ' transações sem checkout'
    END as diagnostico
FROM stats;

-- ===================================================================
-- ✅ PRONTO!
-- ===================================================================
-- RESULTADO:
-- 1. ✅ Todos os checkouts foram criados forçadamente
-- 2. ✅ Links estão prontos para enviar
-- 3. ⚠️ Se função está errada, execute: CORRIGIR-CHECKOUT-3MIN-EXPIRA-24H.sql
-- 4. ⚠️ Se cron job está inativo, precisa ativar no Supabase
--
-- PRÓXIMO PASSO:
-- - Copie os links da seção "LINKS PARA ENVIAR AOS CLIENTES"
-- - Envie para os respectivos clientes
-- - Ou configure Postmark para envio automático
-- ===================================================================

