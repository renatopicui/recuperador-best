-- ===================================================================
-- ⚡ GERAR LINK IMEDIATAMENTE PARA CLIENTE
-- ===================================================================
-- Email: renatopicui1@gmail.com
-- Produto: copo
-- ===================================================================

-- Executar função de criação de checkouts
SELECT '🚀 CRIANDO CHECKOUT...' as status;

SELECT generate_checkout_links_for_pending_payments();

-- ===================================================================

-- Buscar o link criado
SELECT '🔗 LINK PARA ENVIAR AO CLIENTE' as status;

SELECT 
    '📋 COPIE ESTE LINK E ENVIE PARA O CLIENTE' as instrucao,
    'http://localhost:5173/checkout/' || cl.checkout_slug as link_completo,
    cl.checkout_slug,
    CONCAT(
        'Valor original: R$ ', ROUND(cl.amount / 100.0, 2), 
        ' | Com 20% OFF: R$ ', ROUND(cl.final_amount / 100.0, 2),
        ' | Economiza: R$ ', ROUND(cl.discount_amount / 100.0, 2)
    ) as info_desconto,
    TO_CHAR(cl.expires_at, 'DD/MM/YYYY HH24:MI') as expira_em
FROM checkout_links cl
INNER JOIN payments p ON cl.payment_id = p.id
WHERE p.customer_email = 'renatopicui1@gmail.com'
AND p.product_name ILIKE '%copo%'
ORDER BY cl.created_at DESC
LIMIT 1;

-- ===================================================================
-- ✅ COPIE O LINK ACIMA E ENVIE PARA:
-- renatopicui1@gmail.com
-- ===================================================================

