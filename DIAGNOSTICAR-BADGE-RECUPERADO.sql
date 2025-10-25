-- ===================================================================
-- 🔍 DIAGNOSTICAR POR QUE BADGE "RECUPERADO" NÃO APARECE
-- ===================================================================
-- Transação: teste / renatopicui1@gmail.com / camisa
-- ===================================================================

-- PASSO 1: BUSCAR A TRANSAÇÃO
SELECT '🔍 DADOS DA TRANSAÇÃO' as secao;

SELECT 
    id,
    customer_name,
    customer_email,
    product_name,
    amount / 100.0 as valor_reais,
    status,
    created_at,
    converted_from_recovery,
    recovered_at,
    recovery_email_sent_at
FROM payments
WHERE customer_email = 'renatopicui1@gmail.com'
AND product_name ILIKE '%camisa%'
ORDER BY created_at DESC
LIMIT 1;

-- ===================================================================

-- PASSO 2: BUSCAR CHECKOUT LINK ASSOCIADO
SELECT '🔗 CHECKOUT LINK ASSOCIADO' as secao;

SELECT 
    cl.id,
    cl.checkout_slug,
    cl.thank_you_slug,
    cl.payment_status,
    cl.thank_you_accessed_at,
    cl.thank_you_access_count,
    cl.created_at
FROM checkout_links cl
INNER JOIN payments p ON cl.payment_id = p.id
WHERE p.customer_email = 'renatopicui1@gmail.com'
AND p.product_name ILIKE '%camisa%'
ORDER BY cl.created_at DESC
LIMIT 1;

-- ===================================================================

-- PASSO 3: VERIFICAR CONDIÇÕES PARA MOSTRAR O BADGE
SELECT '🎯 ANÁLISE DAS CONDIÇÕES' as secao;

SELECT 
    'CONDIÇÃO PARA MOSTRAR BADGE: checkout.thank_you_slug !== null && payment.status === ''paid''' as regra,
    p.status as payment_status,
    cl.thank_you_slug,
    CASE WHEN p.status = 'paid' THEN '✅ PAGO' ELSE '❌ NÃO PAGO' END as condicao_1_status,
    CASE WHEN cl.thank_you_slug IS NOT NULL THEN '✅ TEM SLUG' ELSE '❌ NÃO TEM SLUG' END as condicao_2_slug,
    CASE 
        WHEN p.status = 'paid' AND cl.thank_you_slug IS NOT NULL 
        THEN '✅ DEVERIA MOSTRAR BADGE!'
        WHEN p.status != 'paid'
        THEN '❌ NÃO MOSTRA: Pagamento não está marcado como pago'
        WHEN cl.thank_you_slug IS NULL
        THEN '❌ NÃO MOSTRA: thank_you_slug não foi gerado'
        ELSE '❓ SITUAÇÃO DESCONHECIDA'
    END as diagnostico
FROM payments p
LEFT JOIN checkout_links cl ON cl.payment_id = p.id
WHERE p.customer_email = 'renatopicui1@gmail.com'
AND p.product_name ILIKE '%camisa%'
ORDER BY p.created_at DESC
LIMIT 1;

-- ===================================================================

-- PASSO 4: VERIFICAR SE TRIGGERS ESTÃO ATIVOS
SELECT '⚡ TRIGGERS ATIVOS' as secao;

SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND (trigger_name LIKE '%thank_you%' OR trigger_name LIKE '%recovery%')
ORDER BY event_object_table, trigger_name;

-- ===================================================================

-- PASSO 5: VERIFICAR HISTÓRICO DE MUDANÇAS DE STATUS
SELECT '📊 DIAGNÓSTICO DETALHADO' as secao;

WITH transacao AS (
    SELECT 
        p.id,
        p.customer_email,
        p.product_name,
        p.status,
        p.converted_from_recovery,
        p.recovered_at,
        cl.checkout_slug,
        cl.thank_you_slug,
        cl.payment_status,
        cl.thank_you_accessed_at
    FROM payments p
    LEFT JOIN checkout_links cl ON cl.payment_id = p.id
    WHERE p.customer_email = 'renatopicui1@gmail.com'
    AND p.product_name ILIKE '%camisa%'
    ORDER BY p.created_at DESC
    LIMIT 1
)
SELECT 
    '🎯 RESULTADO FINAL' as tipo,
    customer_email,
    product_name,
    status as payment_status,
    CASE WHEN checkout_slug IS NOT NULL THEN 'SIM' ELSE 'NÃO' END as tem_checkout,
    CASE WHEN thank_you_slug IS NOT NULL THEN 'SIM (' || thank_you_slug || ')' ELSE 'NÃO' END as tem_thank_you_slug,
    CASE WHEN thank_you_accessed_at IS NOT NULL THEN 'SIM' ELSE 'NÃO' END as pagina_obrigado_acessada,
    CASE WHEN converted_from_recovery THEN 'SIM' ELSE 'NÃO' END as marcado_como_recuperado,
    CASE 
        -- Cenário 1: Tudo correto, deveria mostrar
        WHEN status = 'paid' AND thank_you_slug IS NOT NULL
        THEN '✅ DEVE MOSTRAR BADGE (verifique frontend)'
        
        -- Cenário 2: Pago mas sem thank_you_slug
        WHEN status = 'paid' AND thank_you_slug IS NULL
        THEN '❌ PROBLEMA: Pagamento confirmado mas thank_you_slug não foi gerado (trigger não disparou)'
        
        -- Cenário 3: Tem slug mas não está pago
        WHEN status != 'paid' AND thank_you_slug IS NOT NULL
        THEN '❌ PROBLEMA: tem thank_you_slug mas status não é "paid"'
        
        -- Cenário 4: Não tem checkout
        WHEN checkout_slug IS NULL
        THEN '❌ PROBLEMA: Checkout não foi criado'
        
        -- Cenário 5: Checkout existe mas sem slug
        WHEN checkout_slug IS NOT NULL AND thank_you_slug IS NULL
        THEN '⚠️ AGUARDANDO: Cliente ainda não pagou ou trigger não disparou'
        
        ELSE '❓ SITUAÇÃO DESCONHECIDA'
    END as diagnostico,
    CASE 
        WHEN status = 'paid' AND thank_you_slug IS NULL
        THEN 'Execute: SELECT generate_thank_you_slug_for_payment(''' || id::text || ''')'
        
        WHEN status = 'paid' AND thank_you_slug IS NOT NULL
        THEN 'Badge deveria aparecer. Verifique se Dashboard.tsx está usando "checkout.thank_you_slug"'
        
        ELSE 'Aguarde pagamento ser confirmado'
    END as solucao
FROM transacao;

-- ===================================================================

-- PASSO 6: VERIFICAR O CÓDIGO DO DASHBOARD (LÓGICA DO BADGE)
SELECT '💡 LÓGICA DO BADGE NO DASHBOARD' as secao;

SELECT 
    'O badge aparece quando:' as regra,
    '1. checkout existe (checkout = getCheckoutLink(payment.id))' as condicao_1,
    '2. checkout.thank_you_slug !== null' as condicao_2,
    '3. payment.status === "paid"' as condicao_3,
    'Código: {checkout && checkout.thank_you_slug && payment.status === ''paid''}' as codigo;

-- ===================================================================

-- PASSO 7: SOLUÇÃO IMEDIATA (SE NECESSÁRIO)
SELECT '🔧 SOLUÇÃO IMEDIATA' as secao;

-- Se o pagamento está pago mas não tem thank_you_slug, gerar agora:
-- (DESCOMENTE SE NECESSÁRIO)

-- DO $$
-- DECLARE
--     v_payment_id UUID;
--     v_checkout_id UUID;
--     v_new_slug TEXT;
-- BEGIN
--     -- Buscar payment
--     SELECT p.id INTO v_payment_id
--     FROM payments p
--     WHERE p.customer_email = 'renatopicui1@gmail.com'
--     AND p.product_name ILIKE '%camisa%'
--     AND p.status = 'paid'
--     ORDER BY p.created_at DESC
--     LIMIT 1;
--     
--     IF v_payment_id IS NOT NULL THEN
--         -- Buscar checkout
--         SELECT id INTO v_checkout_id
--         FROM checkout_links
--         WHERE payment_id = v_payment_id
--         AND thank_you_slug IS NULL;
--         
--         IF v_checkout_id IS NOT NULL THEN
--             -- Gerar slug
--             v_new_slug := 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12);
--             
--             -- Atualizar
--             UPDATE checkout_links
--             SET thank_you_slug = v_new_slug
--             WHERE id = v_checkout_id;
--             
--             -- Marcar como recuperado
--             UPDATE payments
--             SET 
--                 converted_from_recovery = TRUE,
--                 recovered_at = NOW()
--             WHERE id = v_payment_id;
--             
--             RAISE NOTICE '✅ thank_you_slug gerado: %', v_new_slug;
--         END IF;
--     END IF;
-- END $$;

-- ===================================================================
-- ✅ RESULTADO
-- ===================================================================
-- Veja a seção "DIAGNÓSTICO DETALHADO" para entender o problema
-- ===================================================================

