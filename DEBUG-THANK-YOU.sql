-- ===================================================================
-- 🔍 DEBUG - Verificar o que aconteceu com ty-2pc2jtyowd28
-- ===================================================================

-- 1. Verificar se o thank_you_slug existe
SELECT 
    '🔍 CHECKOUT' as tipo,
    id,
    checkout_slug,
    thank_you_slug,
    payment_id,
    payment_status,
    thank_you_accessed_at,
    thank_you_access_count,
    created_at
FROM checkout_links
WHERE thank_you_slug = 'ty-2pc2jtyowd28';

-- 2. Verificar o payment relacionado
SELECT 
    '💰 PAYMENT' as tipo,
    p.id,
    p.bestfy_id,
    p.customer_name,
    p.customer_email,
    p.amount / 100.0 as valor_reais,
    p.status,
    p.converted_from_recovery,
    p.recovered_at,
    p.created_at,
    p.updated_at
FROM payments p
WHERE p.id IN (
    SELECT payment_id 
    FROM checkout_links 
    WHERE thank_you_slug = 'ty-2pc2jtyowd28'
);

-- 3. Testar a função manualmente
SELECT access_thank_you_page('ty-2pc2jtyowd28');

-- 4. Verificar novamente após chamar a função
SELECT 
    '✅ DEPOIS DE CHAMAR' as tipo,
    p.bestfy_id,
    p.customer_name,
    p.status,
    p.converted_from_recovery,
    p.recovered_at,
    cl.thank_you_accessed_at,
    cl.thank_you_access_count
FROM checkout_links cl
LEFT JOIN payments p ON cl.payment_id = p.id
WHERE cl.thank_you_slug = 'ty-2pc2jtyowd28';

-- 5. Verificar TODAS as transações recuperadas
SELECT 
    '📊 TODAS RECUPERADAS' as tipo,
    COUNT(*) as total,
    SUM(amount) / 100.0 as valor_total_reais
FROM payments
WHERE converted_from_recovery = TRUE
AND status = 'paid';

-- 6. Listar transações recuperadas
SELECT 
    p.bestfy_id,
    p.customer_name,
    p.amount / 100.0 as valor_reais,
    p.converted_from_recovery,
    p.recovered_at,
    cl.checkout_slug
FROM payments p
INNER JOIN checkout_links cl ON p.id = cl.payment_id
WHERE p.converted_from_recovery = TRUE
ORDER BY p.recovered_at DESC
LIMIT 10;

