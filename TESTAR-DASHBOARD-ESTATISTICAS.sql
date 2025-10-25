-- ===================================================================
-- 📊 TESTAR ESTATÍSTICAS DO DASHBOARD
-- ===================================================================
-- Execute este script para verificar os dados que o Dashboard exibirá
-- ===================================================================

-- 1. VER TODOS OS CHECKOUTS E STATUS DE RECUPERAÇÃO
SELECT 
    '📋 CHECKOUTS' as tipo,
    checkout_slug,
    payment_status,
    thank_you_slug,
    final_amount,
    amount,
    CASE 
        WHEN thank_you_slug IS NOT NULL THEN '✅ RECUPERADO'
        WHEN payment_status = 'paid' AND thank_you_slug IS NULL THEN '⚠️ PAGO MAS SEM SLUG'
        WHEN payment_status = 'pending' THEN '⏳ PENDENTE'
        ELSE '❓ OUTRO'
    END as status_recuperacao,
    created_at
FROM checkout_links
ORDER BY created_at DESC;

-- ===================================================================

-- 2. ESTATÍSTICAS QUE O DASHBOARD EXIBIRÁ
SELECT 
    '📊 ESTATÍSTICAS DO DASHBOARD' as secao,
    COUNT(*) as total_checkouts,
    COUNT(*) FILTER (WHERE thank_you_slug IS NOT NULL) as vendas_recuperadas,
    SUM(final_amount) FILTER (WHERE thank_you_slug IS NOT NULL) as valores_recuperados_centavos,
    ROUND(SUM(final_amount) FILTER (WHERE thank_you_slug IS NOT NULL) / 100.0, 2) as valores_recuperados_reais,
    ROUND(
        (COUNT(*) FILTER (WHERE thank_you_slug IS NOT NULL) * 100.0) / 
        NULLIF(COUNT(*), 0), 
        2
    ) as taxa_conversao_percentual
FROM checkout_links;

-- ===================================================================

-- 3. DETALHES DOS CHECKOUTS RECUPERADOS
SELECT 
    '💰 CHECKOUTS RECUPERADOS (Detalhes)' as tipo,
    cl.checkout_slug,
    cl.customer_name,
    cl.customer_email,
    cl.product_name,
    cl.amount as valor_original,
    cl.final_amount as valor_com_desconto,
    cl.thank_you_slug,
    cl.thank_you_accessed_at,
    cl.thank_you_access_count,
    cl.payment_status,
    p.status as payment_real_status
FROM checkout_links cl
LEFT JOIN payments p ON cl.payment_id = p.id
WHERE cl.thank_you_slug IS NOT NULL
ORDER BY cl.created_at DESC;

-- ===================================================================

-- 4. CHECKOUTS PAGOS MAS SEM SLUG (Problemas)
SELECT 
    '⚠️ PAGOS SEM thank_you_slug (Problemas)' as tipo,
    cl.checkout_slug,
    cl.payment_status,
    p.status as payment_real_status,
    cl.thank_you_slug,
    cl.created_at
FROM checkout_links cl
LEFT JOIN payments p ON cl.payment_id = p.id
WHERE (cl.payment_status = 'paid' OR p.status = 'paid')
AND cl.thank_you_slug IS NULL
ORDER BY cl.created_at DESC;

-- ===================================================================

-- 5. EXEMPLO DE COMO SERIA NO DASHBOARD
SELECT 
    '🎯 EXEMPLO DE CARDS DO DASHBOARD' as titulo;

-- Card 1: Vendas Recuperadas
SELECT 
    '💰 Vendas Recuperadas' as card,
    COUNT(*) as quantidade,
    COUNT(*) || ' vendas' as display
FROM checkout_links
WHERE thank_you_slug IS NOT NULL;

-- Card 2: Valores Recuperados
SELECT 
    '💵 Valores Recuperados' as card,
    SUM(final_amount) as total_centavos,
    'R$ ' || TO_CHAR(SUM(final_amount) / 100.0, 'FM999G999G990D00') as display
FROM checkout_links
WHERE thank_you_slug IS NOT NULL;

-- Card 3: Taxa de Conversão
SELECT 
    '📈 Taxa de Conversão' as card,
    ROUND(
        (COUNT(*) FILTER (WHERE thank_you_slug IS NOT NULL) * 100.0) / 
        NULLIF(COUNT(*), 0), 
        2
    ) as percentual,
    ROUND(
        (COUNT(*) FILTER (WHERE thank_you_slug IS NOT NULL) * 100.0) / 
        NULLIF(COUNT(*), 0), 
        2
    ) || '%' as display
FROM checkout_links;

-- ===================================================================

-- 6. VERIFICAÇÃO DE INTEGRIDADE
SELECT 
    '🔍 VERIFICAÇÃO DE INTEGRIDADE' as tipo,
    COUNT(*) as total_checkouts,
    COUNT(*) FILTER (WHERE payment_status = 'paid') as checkouts_pagos,
    COUNT(*) FILTER (WHERE thank_you_slug IS NOT NULL) as com_thank_you_slug,
    COUNT(*) FILTER (WHERE payment_status = 'paid' AND thank_you_slug IS NULL) as pagos_sem_slug,
    CASE 
        WHEN COUNT(*) FILTER (WHERE payment_status = 'paid' AND thank_you_slug IS NULL) = 0 
        THEN '✅ TUDO OK'
        ELSE '⚠️ TEM PAGOS SEM SLUG - EXECUTE APLICAR-TRIGGER-DEFINITIVO.sql'
    END as diagnostico
FROM checkout_links;

-- ===================================================================
-- 📋 INTERPRETAÇÃO DOS RESULTADOS
-- ===================================================================
--
-- RESULTADO ESPERADO (Exemplo):
--
-- 📊 ESTATÍSTICAS DO DASHBOARD:
-- - total_checkouts: 3
-- - vendas_recuperadas: 2
-- - valores_recuperados_reais: 7.20
-- - taxa_conversao_percentual: 66.67
--
-- ISSO SIGNIFICA:
-- - Dashboard mostrará "Vendas Recuperadas: 2"
-- - Dashboard mostrará "Valores Recuperados: R$ 7,20"
-- - Dashboard mostrará "Taxa de Conversão: 66,67%"
--
-- ===================================================================

