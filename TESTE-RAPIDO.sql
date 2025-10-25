-- ===================================================================
-- 🧪 TESTE RÁPIDO - VERIFICAR SE ESTÁ FUNCIONANDO
-- ===================================================================
-- Execute este script para testar se tudo voltou a funcionar
-- ===================================================================

-- TESTE 1: Ver se há pagamentos esperando checkout
SELECT '🔍 TESTE 1: PAGAMENTOS SEM CHECKOUT' as teste;

SELECT 
    p.id,
    p.customer_email,
    p.created_at,
    ROUND(EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 60, 2) as minutos_desde_criacao,
    CASE 
        WHEN EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 60 >= 3 
        THEN '✅ Passou 3 minutos - DEVE criar checkout'
        ELSE '⏳ Faltam ' || ROUND(3 - EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 60, 1)::text || ' minutos'
    END as status
FROM payments p
LEFT JOIN checkout_links cl ON cl.payment_id = p.id
WHERE p.status = 'waiting_payment'
AND cl.id IS NULL
ORDER BY p.created_at DESC
LIMIT 5;

-- ===================================================================

-- TESTE 2: Executar função manualmente
SELECT '🚀 TESTE 2: EXECUTAR FUNÇÃO' as teste;

SELECT generate_checkout_links_for_pending_payments() as resultado;

-- Resultado esperado: {"created": X, "errors": 0}

-- ===================================================================

-- TESTE 3: Ver checkouts criados recentemente
SELECT '✅ TESTE 3: CHECKOUTS CRIADOS' as teste;

SELECT 
    cl.checkout_slug,
    cl.customer_email,
    cl.created_at,
    cl.expires_at,
    ROUND(EXTRACT(EPOCH FROM (cl.expires_at - cl.created_at)) / 3600, 2) as horas_expiracao,
    CASE 
        WHEN ROUND(EXTRACT(EPOCH FROM (cl.expires_at - cl.created_at)) / 3600, 2) = 24
        THEN '✅ 24 horas (correto!)'
        WHEN ROUND(EXTRACT(EPOCH FROM (cl.expires_at - cl.created_at)) / 3600, 2) < 1
        THEN '❌ Menos de 1 hora (errado!)'
        ELSE '⚠️ ' || ROUND(EXTRACT(EPOCH FROM (cl.expires_at - cl.created_at)) / 3600, 2)::text || ' horas'
    END as validacao
FROM checkout_links cl
WHERE cl.created_at > NOW() - INTERVAL '30 minutes'
ORDER BY cl.created_at DESC
LIMIT 10;

-- ===================================================================

-- TESTE 4: Ver configuração da coluna
SELECT '⚙️ TESTE 4: CONFIGURAÇÃO' as teste;

SELECT 
    column_default as expires_at_default,
    CASE 
        WHEN column_default LIKE '%24:00:00%' 
        THEN '✅ Configurado para 24 horas'
        WHEN column_default LIKE '%00:15:00%'
        THEN '❌ Ainda em 15 minutos'
        ELSE '⚠️ Valor: ' || column_default
    END as validacao
FROM information_schema.columns
WHERE table_name = 'checkout_links'
AND column_name = 'expires_at';

-- ===================================================================

-- TESTE 5: Ver função (ver o tempo de espera)
SELECT '🔧 TESTE 5: FUNÇÃO' as teste;

SELECT 
    routine_name,
    CASE 
        WHEN routine_definition LIKE '%3 minutes%'
        THEN '✅ Função correta (espera 3 minutos)'
        WHEN routine_definition LIKE '%1 hour%'
        THEN '❌ Função errada (espera 1 hora)'
        ELSE '⚠️ Verificar manualmente'
    END as validacao
FROM information_schema.routines
WHERE routine_name = 'generate_checkout_links_for_pending_payments'
AND routine_schema = 'public';

-- ===================================================================

-- TESTE 6: Resumo Final
SELECT '📊 RESUMO FINAL' as tipo;

WITH config AS (
    SELECT 
        CASE 
            WHEN column_default LIKE '%24:00:00%' THEN true
            ELSE false
        END as expiracao_24h
    FROM information_schema.columns
    WHERE table_name = 'checkout_links' AND column_name = 'expires_at'
),
funcao AS (
    SELECT 
        CASE 
            WHEN routine_definition LIKE '%3 minutes%' THEN true
            ELSE false
        END as espera_3min
    FROM information_schema.routines
    WHERE routine_name = 'generate_checkout_links_for_pending_payments'
),
checkouts AS (
    SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (
            WHERE ROUND(EXTRACT(EPOCH FROM (expires_at - created_at)) / 3600, 1) = 24.0
        ) as com_24h
    FROM checkout_links
    WHERE created_at > NOW() - INTERVAL '1 day'
)
SELECT 
    CASE WHEN config.expiracao_24h THEN '✅' ELSE '❌' END || ' Expiração em 24h' as teste_1,
    CASE WHEN funcao.espera_3min THEN '✅' ELSE '❌' END || ' Cria após 3 minutos' as teste_2,
    CASE 
        WHEN checkouts.total > 0 AND checkouts.com_24h = checkouts.total 
        THEN '✅ Checkouts corretos'
        WHEN checkouts.total = 0
        THEN '⚠️ Nenhum checkout recente'
        ELSE '❌ ' || checkouts.com_24h::text || ' de ' || checkouts.total::text || ' corretos'
    END as teste_3,
    CASE 
        WHEN config.expiracao_24h AND funcao.espera_3min
        THEN '✅✅✅ TUDO FUNCIONANDO!'
        ELSE '❌ PRECISA EXECUTAR CORRIGIR-CHECKOUT-3MIN-EXPIRA-24H.sql'
    END as resultado_final
FROM config, funcao, checkouts;

-- ===================================================================
-- INTERPRETAÇÃO DOS RESULTADOS
-- ===================================================================
-- 
-- TESTE 1: Deve mostrar pagamentos que aguardam checkout
-- TESTE 2: Deve retornar {"created": X, "errors": 0}
-- TESTE 3: Deve mostrar checkouts com "24 horas (correto!)"
-- TESTE 4: Deve mostrar "✅ Configurado para 24 horas"
-- TESTE 5: Deve mostrar "✅ Função correta (espera 3 minutos)"
-- TESTE 6 (RESUMO): Deve mostrar "✅✅✅ TUDO FUNCIONANDO!"
--
-- SE VER "❌" EM QUALQUER TESTE:
-- Execute: CORRIGIR-CHECKOUT-3MIN-EXPIRA-24H.sql
-- ===================================================================

