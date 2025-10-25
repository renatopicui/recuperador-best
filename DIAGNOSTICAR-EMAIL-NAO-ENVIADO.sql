-- ===================================================================
-- 🔍 DIAGNOSTICAR POR QUE EMAIL DE RECUPERAÇÃO NÃO FOI ENVIADO
-- ===================================================================
-- Email: renatopicui1@gmail.com
-- ===================================================================

-- PASSO 1: BUSCAR O PAGAMENTO
SELECT '🔍 BUSCANDO PAGAMENTO...' as status;

SELECT 
    '📋 DADOS DO PAGAMENTO' as tipo,
    id,
    user_id,
    bestfy_id,
    customer_name,
    customer_email,
    amount,
    status,
    created_at,
    recovery_email_sent_at,
    CASE 
        WHEN recovery_email_sent_at IS NOT NULL 
        THEN '✅ Email JÁ foi enviado em: ' || recovery_email_sent_at::text
        ELSE '❌ Email NÃO foi enviado'
    END as status_email,
    CASE 
        WHEN created_at < NOW() - INTERVAL '1 hour'
        THEN '✅ Passou 1 hora (deveria ter enviado)'
        ELSE '⏳ Ainda não passou 1 hora (aguardando)'
    END as tempo_desde_criacao,
    EXTRACT(EPOCH FROM (NOW() - created_at)) / 3600 as horas_desde_criacao
FROM payments
WHERE customer_email = 'renatopicui1@gmail.com'
ORDER BY created_at DESC;

-- ===================================================================

-- PASSO 2: VERIFICAR CONFIGURAÇÃO DE EMAIL DO USUÁRIO
SELECT '🔍 VERIFICANDO CONFIGURAÇÃO DE EMAIL...' as status;

SELECT 
    '📧 EMAIL_SETTINGS' as tipo,
    es.id,
    es.user_id,
    es.from_email,
    es.from_name,
    es.is_active,
    CASE 
        WHEN es.postmark_token IS NOT NULL 
        THEN '✅ Token Postmark configurado'
        ELSE '❌ Token Postmark NÃO configurado'
    END as postmark_status,
    es.created_at
FROM email_settings es
WHERE es.user_id IN (
    SELECT user_id 
    FROM payments 
    WHERE customer_email = 'renatopicui1@gmail.com'
);

-- Se não encontrar configuração
SELECT 
    '⚠️ DIAGNÓSTICO' as tipo,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM email_settings 
            WHERE user_id IN (
                SELECT user_id FROM payments 
                WHERE customer_email = 'renatopicui1@gmail.com'
            )
        )
        THEN '❌ PROBLEMA: Usuário NÃO tem email_settings configurado!'
        ELSE '✅ Configuração de email existe'
    END as resultado;

-- ===================================================================

-- PASSO 3: VERIFICAR SE HÁ CHECKOUT LINK CRIADO
SELECT '🔍 VERIFICANDO CHECKOUT LINKS...' as status;

SELECT 
    '🔗 CHECKOUT_LINKS' as tipo,
    cl.id,
    cl.checkout_slug,
    cl.thank_you_slug,
    cl.payment_status,
    cl.created_at,
    cl.expires_at,
    'http://localhost:5173/checkout/' || cl.checkout_slug as link_completo,
    CASE 
        WHEN cl.id IS NOT NULL 
        THEN '✅ Checkout link EXISTE'
        ELSE '❌ Checkout link NÃO foi criado'
    END as status_checkout
FROM checkout_links cl
WHERE cl.payment_id IN (
    SELECT id FROM payments 
    WHERE customer_email = 'renatopicui1@gmail.com'
);

-- Se não encontrar checkout
SELECT 
    '⚠️ DIAGNÓSTICO' as tipo,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM checkout_links 
            WHERE payment_id IN (
                SELECT id FROM payments 
                WHERE customer_email = 'renatopicui1@gmail.com'
            )
        )
        THEN '❌ PROBLEMA: Checkout link NÃO foi criado!'
        ELSE '✅ Checkout link existe'
    END as resultado;

-- ===================================================================

-- PASSO 4: VERIFICAR CRITÉRIOS PARA ENVIO DE EMAIL
SELECT '🔍 VERIFICANDO CRITÉRIOS...' as status;

SELECT 
    '📊 ANÁLISE DE CRITÉRIOS' as tipo,
    p.customer_email,
    p.status,
    p.recovery_email_sent_at,
    p.created_at,
    CASE 
        WHEN p.status = 'waiting_payment' 
        THEN '✅ Status correto (waiting_payment)'
        ELSE '❌ Status incorreto: ' || p.status
    END as criterio_1_status,
    CASE 
        WHEN p.created_at < NOW() - INTERVAL '1 hour'
        THEN '✅ Passou 1 hora'
        ELSE '❌ Ainda não passou 1 hora'
    END as criterio_2_tempo,
    CASE 
        WHEN p.recovery_email_sent_at IS NULL
        THEN '✅ Email ainda não foi enviado'
        ELSE '❌ Email já foi enviado'
    END as criterio_3_nao_enviado,
    CASE 
        WHEN p.status = 'waiting_payment' 
        AND p.created_at < NOW() - INTERVAL '1 hour'
        AND p.recovery_email_sent_at IS NULL
        THEN '✅ DEVERIA ENVIAR EMAIL!'
        ELSE '❌ NÃO deve enviar (não atende critérios)'
    END as resultado_final
FROM payments p
WHERE p.customer_email = 'renatopicui1@gmail.com'
ORDER BY p.created_at DESC;

-- ===================================================================

-- PASSO 5: VERIFICAR SE CRON JOB ESTÁ ATIVO
SELECT '🔍 VERIFICANDO CRON JOBS...' as status;

SELECT 
    '⏰ CRON JOBS' as tipo,
    jobname,
    schedule,
    active,
    CASE 
        WHEN active THEN '✅ Ativo'
        ELSE '❌ Inativo'
    END as status_cron
FROM cron.job
WHERE jobname LIKE '%recovery%' OR jobname LIKE '%email%';

-- ===================================================================

-- PASSO 6: RESUMO DO DIAGNÓSTICO
SELECT '📋 RESUMO DO DIAGNÓSTICO' as status;

WITH payment_info AS (
    SELECT 
        id,
        user_id,
        customer_email,
        status,
        recovery_email_sent_at,
        created_at,
        EXTRACT(EPOCH FROM (NOW() - created_at)) / 3600 as horas_desde_criacao
    FROM payments
    WHERE customer_email = 'renatopicui1@gmail.com'
    ORDER BY created_at DESC
    LIMIT 1
),
email_config AS (
    SELECT COUNT(*) > 0 as tem_config
    FROM email_settings
    WHERE user_id IN (SELECT user_id FROM payment_info)
),
checkout_link AS (
    SELECT COUNT(*) > 0 as tem_checkout
    FROM checkout_links
    WHERE payment_id IN (SELECT id FROM payment_info)
)
SELECT 
    '🎯 DIAGNÓSTICO FINAL' as tipo,
    pi.customer_email,
    pi.status as payment_status,
    ROUND(pi.horas_desde_criacao, 2) as horas_desde_criacao,
    CASE WHEN ec.tem_config THEN 'SIM' ELSE 'NÃO' END as tem_email_config,
    CASE WHEN cl.tem_checkout THEN 'SIM' ELSE 'NÃO' END as tem_checkout_link,
    CASE WHEN pi.recovery_email_sent_at IS NULL THEN 'NÃO' ELSE 'SIM' END as email_enviado,
    CASE 
        -- Problema 1: Não tem configuração de email
        WHEN NOT ec.tem_config 
        THEN '❌ PROBLEMA: Usuário não configurou Postmark (email_settings)'
        
        -- Problema 2: Ainda não passou 1 hora
        WHEN pi.horas_desde_criacao < 1
        THEN '⏳ AGUARDANDO: Ainda não passou 1 hora (faltam ' || 
             ROUND((1 - pi.horas_desde_criacao) * 60, 0)::text || ' minutos)'
        
        -- Problema 3: Pagamento já foi pago
        WHEN pi.status != 'waiting_payment'
        THEN '✅ OK: Pagamento já foi confirmado (status: ' || pi.status || ')'
        
        -- Problema 4: Email já foi enviado
        WHEN pi.recovery_email_sent_at IS NOT NULL
        THEN '✅ Email já foi enviado em: ' || pi.recovery_email_sent_at::text
        
        -- Problema 5: Cron job não rodou ainda
        WHEN pi.status = 'waiting_payment' 
        AND pi.horas_desde_criacao >= 1
        AND pi.recovery_email_sent_at IS NULL
        AND ec.tem_config
        THEN '⚠️ PROBLEMA: Atende todos os critérios mas email não foi enviado! Cron job pode não estar ativo.'
        
        ELSE '❓ Situação desconhecida'
    END as diagnostico
FROM payment_info pi
CROSS JOIN email_config ec
CROSS JOIN checkout_link cl;

-- ===================================================================

-- PASSO 7: SOLUÇÃO SUGERIDA
SELECT '💡 SOLUÇÕES POSSÍVEIS' as status;

SELECT 
    '💡 AÇÃO RECOMENDADA' as tipo,
    CASE 
        WHEN NOT EXISTS (
            SELECT 1 FROM email_settings 
            WHERE user_id IN (
                SELECT user_id FROM payments 
                WHERE customer_email = 'renatopicui1@gmail.com'
            )
        )
        THEN 'Configurar Postmark no Dashboard → Configurar Email'
        
        WHEN EXISTS (
            SELECT 1 FROM payments 
            WHERE customer_email = 'renatopicui1@gmail.com'
            AND status = 'waiting_payment'
            AND created_at < NOW() - INTERVAL '1 hour'
            AND recovery_email_sent_at IS NULL
        )
        THEN 'Executar manualmente a função send_recovery_emails ou aguardar próximo cron (roda a cada 1h)'
        
        ELSE 'Email será enviado automaticamente quando passar 1 hora'
    END as solucao;

-- ===================================================================

-- PASSO 8: FORÇAR ENVIO MANUAL (OPCIONAL)
-- Descomente apenas se quiser enviar email AGORA, sem esperar cron
-- SELECT '⚠️ PARA FORÇAR ENVIO MANUAL, EXECUTE:' as status;
-- SELECT 'SELECT net.http_post(url := ''https://SEU-PROJETO.supabase.co/functions/v1/send-recovery-emails'')' as comando;

-- ===================================================================
-- ✅ DIAGNÓSTICO COMPLETO
-- ===================================================================
-- Este script mostra exatamente por que o email não foi enviado
-- e sugere a solução apropriada
-- ===================================================================

