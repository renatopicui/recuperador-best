-- ===================================================================
-- 🔍 VERIFICAR TRANSAÇÃO RECUPERADA
-- ===================================================================
-- Execute este script no Supabase SQL Editor para verificar
-- ===================================================================

-- 1. Verificar o checkout 9m5k48gx
SELECT 
    '🔍 CHECKOUT' as tipo,
    checkout_slug,
    payment_id,
    payment_status,
    thank_you_slug,
    thank_you_accessed_at,
    thank_you_access_count
FROM checkout_links
WHERE checkout_slug = '9m5k48gx';

-- 2. Buscar o payment relacionado
SELECT 
    '💰 PAYMENT' as tipo,
    p.id,
    p.bestfy_id,
    p.customer_name,
    p.amount,
    p.status,
    p.converted_from_recovery,
    p.recovered_at,
    p.created_at
FROM payments p
WHERE p.id IN (
    SELECT payment_id 
    FROM checkout_links 
    WHERE checkout_slug = '9m5k48gx'
);

-- 3. Verificar se a função access_thank_you_page foi chamada
SELECT 
    '📊 RESUMO' as tipo,
    CASE 
        WHEN thank_you_accessed_at IS NOT NULL THEN '✅ Thank you page foi acessada'
        ELSE '❌ Thank you page NÃO foi acessada'
    END as thank_you_status,
    CASE 
        WHEN p.converted_from_recovery = TRUE THEN '✅ Marcado como recuperado'
        WHEN p.converted_from_recovery = FALSE THEN '❌ NÃO marcado como recuperado'
        ELSE '⚠️ Campo converted_from_recovery é NULL'
    END as recovery_status,
    CASE 
        WHEN p.recovered_at IS NOT NULL THEN '✅ Data de recuperação registrada'
        ELSE '❌ Data de recuperação NÃO registrada'
    END as recovered_at_status
FROM checkout_links cl
LEFT JOIN payments p ON cl.payment_id = p.id
WHERE cl.checkout_slug = '9m5k48gx';

-- ===================================================================
-- 🔧 SE NÃO ESTIVER MARCADO, EXECUTE ISSO:
-- ===================================================================

-- Marcar manualmente como recuperado (caso a função não tenha funcionado)
DO $$
DECLARE
    v_payment_id UUID;
BEGIN
    -- Buscar o payment_id
    SELECT payment_id INTO v_payment_id
    FROM checkout_links
    WHERE checkout_slug = '9m5k48gx';
    
    IF v_payment_id IS NOT NULL THEN
        -- Atualizar o payment
        UPDATE payments
        SET 
            converted_from_recovery = TRUE,
            recovered_at = COALESCE(recovered_at, NOW())
        WHERE id = v_payment_id
        AND status = 'paid';
        
        -- Atualizar o checkout_links
        UPDATE checkout_links
        SET 
            thank_you_accessed_at = COALESCE(thank_you_accessed_at, NOW()),
            thank_you_access_count = COALESCE(thank_you_access_count, 0) + 1
        WHERE checkout_slug = '9m5k48gx';
        
        RAISE NOTICE '✅ Transação 9m5k48gx marcada como recuperada!';
    ELSE
        RAISE NOTICE '❌ Payment não encontrado para checkout 9m5k48gx';
    END IF;
END $$;

-- Verificar novamente após marcar
SELECT 
    '✅ VERIFICAÇÃO FINAL' as tipo,
    p.bestfy_id,
    p.customer_name,
    p.amount / 100.0 as valor_reais,
    p.status,
    p.converted_from_recovery,
    p.recovered_at
FROM checkout_links cl
LEFT JOIN payments p ON cl.payment_id = p.id
WHERE cl.checkout_slug = '9m5k48gx';

