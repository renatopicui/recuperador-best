-- ===================================================================
-- 🔍 VERIFICAR DADOS QUE O DASHBOARD DEVERIA MOSTRAR
-- ===================================================================

-- 1. Verificar TODAS as transações do usuário
SELECT 
    '📊 TODAS AS TRANSAÇÕES' as titulo,
    bestfy_id,
    customer_name,
    amount / 100.0 as valor_reais,
    status,
    converted_from_recovery,
    recovered_at,
    created_at
FROM payments
ORDER BY created_at DESC
LIMIT 20;

-- 2. Filtrar APENAS as RECUPERADAS
SELECT 
    '💰 TRANSAÇÕES RECUPERADAS' as titulo,
    COUNT(*) as quantidade,
    SUM(amount) / 100.0 as valor_total_reais
FROM payments
WHERE converted_from_recovery = TRUE
AND status = 'paid';

-- 3. Listar detalhes das recuperadas
SELECT 
    '📋 LISTA RECUPERADAS' as titulo,
    bestfy_id,
    customer_name,
    amount / 100.0 as valor_reais,
    status,
    converted_from_recovery,
    recovered_at
FROM payments
WHERE converted_from_recovery = TRUE
AND status = 'paid'
ORDER BY recovered_at DESC;

-- 4. Verificar especificamente ty-2pc2jtyowd28
SELECT 
    '🎯 TRANSAÇÃO ty-2pc2jtyowd28' as titulo,
    p.bestfy_id,
    p.customer_name,
    p.amount / 100.0 as valor_reais,
    p.status,
    p.converted_from_recovery,
    p.recovered_at,
    cl.checkout_slug,
    cl.thank_you_slug,
    cl.thank_you_accessed_at
FROM payments p
INNER JOIN checkout_links cl ON p.id = cl.payment_id
WHERE cl.thank_you_slug = 'ty-2pc2jtyowd28';

-- 5. Verificar o tipo de dados da coluna
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'payments'
AND column_name IN ('converted_from_recovery', 'recovered_at');

-- 6. Contar por status de recuperação
SELECT 
    '📊 DISTRIBUIÇÃO' as titulo,
    CASE 
        WHEN converted_from_recovery = TRUE THEN 'Recuperadas'
        WHEN converted_from_recovery = FALSE THEN 'Não Recuperadas'
        WHEN converted_from_recovery IS NULL THEN 'NULL (não configurado)'
    END as tipo,
    COUNT(*) as quantidade,
    SUM(amount) / 100.0 as valor_total
FROM payments
WHERE status = 'paid'
GROUP BY converted_from_recovery
ORDER BY converted_from_recovery DESC NULLS LAST;

