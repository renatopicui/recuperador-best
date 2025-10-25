-- ===================================================================
-- 🚨 RESOLVER TRANSAÇÃO ESPECÍFICA
-- ===================================================================
-- Cliente: teste
-- Email: renatopicui1@gmail.com
-- Produto: copo
-- ===================================================================

-- PASSO 1: ENCONTRAR A TRANSAÇÃO
SELECT '🔍 BUSCANDO TRANSAÇÃO...' as status;

SELECT 
    '📋 DADOS DA TRANSAÇÃO' as tipo,
    id,
    customer_name,
    customer_email,
    product_name,
    amount,
    status,
    created_at,
    recovery_email_sent_at,
    EXTRACT(EPOCH FROM (NOW() - created_at)) / 60 as minutos_desde_criacao
FROM payments
WHERE customer_email = 'renatopicui1@gmail.com'
AND product_name ILIKE '%copo%'
ORDER BY created_at DESC
LIMIT 1;

-- ===================================================================
-- PASSO 2: VERIFICAR SE JÁ TEM CHECKOUT
-- ===================================================================

SELECT '🔍 VERIFICANDO CHECKOUT...' as status;

SELECT 
    '🔗 CHECKOUT' as tipo,
    cl.checkout_slug,
    cl.payment_status,
    cl.expires_at,
    'http://localhost:5173/checkout/' || cl.checkout_slug as link_completo
FROM checkout_links cl
INNER JOIN payments p ON cl.payment_id = p.id
WHERE p.customer_email = 'renatopicui1@gmail.com'
AND p.product_name ILIKE '%copo%'
ORDER BY cl.created_at DESC
LIMIT 1;

-- ===================================================================
-- PASSO 3: CRIAR CHECKOUT SE NÃO EXISTE
-- ===================================================================

SELECT '🔧 CRIANDO/VERIFICANDO CHECKOUT...' as status;

-- Executar função de criação de checkouts
SELECT generate_checkout_links_for_pending_payments() as resultado;

-- ===================================================================
-- PASSO 4: VERIFICAR NOVAMENTE SE CHECKOUT FOI CRIADO
-- ===================================================================

SELECT '✅ VERIFICANDO RESULTADO...' as status;

SELECT 
    '🎯 CHECKOUT CRIADO' as tipo,
    cl.checkout_slug,
    cl.payment_status,
    cl.final_amount,
    cl.discount_amount,
    cl.expires_at,
    'http://localhost:5173/checkout/' || cl.checkout_slug as link_para_enviar,
    CASE 
        WHEN cl.expires_at > NOW() THEN '✅ Válido'
        ELSE '❌ Expirado'
    END as status_checkout,
    ROUND(EXTRACT(EPOCH FROM (cl.expires_at - cl.created_at)) / 3600, 2) as horas_validade
FROM checkout_links cl
INNER JOIN payments p ON cl.payment_id = p.id
WHERE p.customer_email = 'renatopicui1@gmail.com'
AND p.product_name ILIKE '%copo%'
ORDER BY cl.created_at DESC
LIMIT 1;

-- ===================================================================
-- PASSO 5: VERIFICAR CONFIGURAÇÃO DE EMAIL
-- ===================================================================

SELECT '📧 VERIFICANDO CONFIGURAÇÃO DE EMAIL...' as status;

SELECT 
    '⚙️ EMAIL SETTINGS' as tipo,
    es.from_email,
    es.from_name,
    es.is_active,
    CASE 
        WHEN es.postmark_token IS NOT NULL 
        THEN '✅ Token Postmark configurado'
        ELSE '❌ Token NÃO configurado'
    END as postmark_status
FROM email_settings es
INNER JOIN payments p ON es.user_id = p.user_id
WHERE p.customer_email = 'renatopicui1@gmail.com'
AND p.product_name ILIKE '%copo%'
LIMIT 1;

-- ===================================================================
-- PASSO 6: MARCAR COMO PRONTO PARA ENVIO DE EMAIL
-- ===================================================================

-- Se o checkout foi criado mas o email não foi marcado como enviado,
-- você pode forçar o reenvio assim:

-- UPDATE payments
-- SET recovery_email_sent_at = NULL
-- WHERE customer_email = 'renatopicui1@gmail.com'
-- AND product_name ILIKE '%copo%'
-- AND status = 'waiting_payment';

-- Depois execute o cron job de emails manualmente

-- ===================================================================
-- PASSO 7: RESUMO FINAL
-- ===================================================================

SELECT '📊 RESUMO FINAL' as status;

WITH transacao AS (
    SELECT 
        p.id,
        p.customer_email,
        p.product_name,
        p.status,
        p.created_at,
        p.recovery_email_sent_at,
        EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 60 as minutos
    FROM payments p
    WHERE p.customer_email = 'renatopicui1@gmail.com'
    AND p.product_name ILIKE '%copo%'
    ORDER BY p.created_at DESC
    LIMIT 1
),
checkout AS (
    SELECT 
        cl.checkout_slug,
        cl.payment_status
    FROM checkout_links cl
    INNER JOIN transacao t ON cl.payment_id = t.id
    LIMIT 1
),
email_config AS (
    SELECT 
        COUNT(*) > 0 as tem_config
    FROM email_settings es
    INNER JOIN transacao t ON es.user_id IN (
        SELECT user_id FROM payments WHERE id = t.id
    )
)
SELECT 
    '🎯 DIAGNÓSTICO FINAL' as tipo,
    t.customer_email,
    t.product_name,
    t.status as payment_status,
    ROUND(t.minutos, 1) as minutos_desde_criacao,
    CASE WHEN c.checkout_slug IS NOT NULL THEN 'SIM' ELSE 'NÃO' END as tem_checkout,
    COALESCE(c.checkout_slug, 'NÃO CRIADO') as checkout_slug,
    CASE WHEN ec.tem_config THEN 'SIM' ELSE 'NÃO' END as tem_email_config,
    CASE WHEN t.recovery_email_sent_at IS NULL THEN 'NÃO' ELSE 'SIM' END as email_enviado,
    CASE 
        WHEN c.checkout_slug IS NULL 
        THEN '❌ PROBLEMA: Checkout não foi criado! Execute generate_checkout_links_for_pending_payments()'
        WHEN NOT ec.tem_config
        THEN '❌ PROBLEMA: Email não configurado! Configure Postmark no Dashboard'
        WHEN t.recovery_email_sent_at IS NULL
        THEN '⚠️ Checkout existe mas email não foi enviado. Execute send-recovery-emails'
        ELSE '✅ Tudo OK, email já foi enviado'
    END as diagnostico,
    CASE 
        WHEN c.checkout_slug IS NOT NULL
        THEN 'http://localhost:5173/checkout/' || c.checkout_slug
        ELSE 'Checkout não existe'
    END as link_para_cliente
FROM transacao t
CROSS JOIN checkout
CROSS JOIN email_config ec;

-- ===================================================================
-- 🎯 AÇÃO IMEDIATA
-- ===================================================================

SELECT '💡 PRÓXIMOS PASSOS' as tipo;

-- Se o checkout foi criado, copie o link acima e envie manualmente
-- Ou execute a edge function send-recovery-emails

-- Comando para chamar edge function (se configurada):
-- SELECT net.http_post(
--     url := 'https://SEU-PROJETO.supabase.co/functions/v1/send-recovery-emails'
-- );

-- ===================================================================
-- ✅ RESULTADO ESPERADO
-- ===================================================================
-- 1. ✅ Transação encontrada
-- 2. ✅ Checkout criado (ou será criado agora)
-- 3. ✅ Link disponível para enviar ao cliente
-- 4. ⚠️ Se Postmark não configurado, envie o link manualmente
-- ===================================================================

