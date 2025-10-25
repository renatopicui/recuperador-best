-- ===================================================================
-- 🔥 FORÇAR ATUALIZAÇÃO - EXECUTE AGORA NO SUPABASE
-- ===================================================================

-- PASSO 1: Verificar se as colunas existem
SELECT 
    '🔍 VERIFICAR COLUNAS' as titulo,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'payments'
AND column_name IN ('converted_from_recovery', 'recovered_at')
ORDER BY column_name;

-- PASSO 2: Adicionar colunas se não existirem
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'payments' AND column_name = 'converted_from_recovery'
    ) THEN
        ALTER TABLE payments ADD COLUMN converted_from_recovery BOOLEAN DEFAULT FALSE;
        RAISE NOTICE '✅ Coluna converted_from_recovery ADICIONADA';
    ELSE
        RAISE NOTICE '✓ Coluna converted_from_recovery JÁ EXISTE';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'payments' AND column_name = 'recovered_at'
    ) THEN
        ALTER TABLE payments ADD COLUMN recovered_at TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE '✅ Coluna recovered_at ADICIONADA';
    ELSE
        RAISE NOTICE '✓ Coluna recovered_at JÁ EXISTE';
    END IF;
END $$;

-- PASSO 3: Marcar TODAS as transações que acessaram página de obrigado
UPDATE payments p
SET 
    converted_from_recovery = TRUE,
    recovered_at = COALESCE(p.recovered_at, cl.thank_you_accessed_at, NOW())
FROM checkout_links cl
WHERE p.id = cl.payment_id
AND p.status = 'paid'
AND cl.thank_you_accessed_at IS NOT NULL;

-- PASSO 4: Marcar especificamente ty-2pc2jtyowd28 (força manual)
UPDATE payments p
SET 
    converted_from_recovery = TRUE,
    recovered_at = COALESCE(p.recovered_at, NOW())
FROM checkout_links cl
WHERE p.id = cl.payment_id
AND cl.thank_you_slug = 'ty-2pc2jtyowd28'
AND p.status = 'paid';

UPDATE checkout_links
SET 
    thank_you_accessed_at = COALESCE(thank_you_accessed_at, NOW()),
    thank_you_access_count = COALESCE(thank_you_access_count, 0) + 1
WHERE thank_you_slug = 'ty-2pc2jtyowd28';

-- PASSO 5: Verificar TODAS as transações recuperadas
SELECT 
    '✅ TRANSAÇÕES RECUPERADAS' as titulo,
    COUNT(*) as quantidade,
    SUM(amount) / 100.0 as valor_total_reais
FROM payments
WHERE converted_from_recovery = TRUE
AND status = 'paid';

-- PASSO 6: Listar detalhes
SELECT 
    '📋 DETALHES DAS RECUPERADAS' as titulo,
    p.bestfy_id,
    p.customer_name,
    p.amount / 100.0 as valor_reais,
    p.status,
    p.converted_from_recovery,
    p.recovered_at,
    cl.checkout_slug,
    cl.thank_you_slug
FROM payments p
LEFT JOIN checkout_links cl ON p.id = cl.payment_id
WHERE p.converted_from_recovery = TRUE
AND p.status = 'paid'
ORDER BY p.recovered_at DESC;

-- PASSO 7: Verificar especificamente ty-2pc2jtyowd28
SELECT 
    '🎯 ty-2pc2jtyowd28 ESPECÍFICO' as titulo,
    p.bestfy_id,
    p.customer_name,
    p.customer_email,
    p.amount / 100.0 as valor_reais,
    p.status,
    p.converted_from_recovery,
    p.recovered_at,
    cl.checkout_slug,
    cl.thank_you_slug,
    cl.thank_you_accessed_at,
    CASE 
        WHEN p.converted_from_recovery = TRUE THEN '✅ VAI APARECER NO DASHBOARD'
        WHEN p.converted_from_recovery = FALSE THEN '❌ NÃO VAI APARECER (FALSE)'
        WHEN p.converted_from_recovery IS NULL THEN '❌ NÃO VAI APARECER (NULL)'
    END as status_dashboard
FROM payments p
INNER JOIN checkout_links cl ON p.id = cl.payment_id
WHERE cl.thank_you_slug = 'ty-2pc2jtyowd28';

-- ===================================================================
-- 🎯 APÓS EXECUTAR ESTE SCRIPT:
-- ===================================================================
-- 1. Veja se a última consulta mostra "✅ VAI APARECER NO DASHBOARD"
-- 2. Se sim, vá para o Dashboard: http://localhost:5173
-- 3. Pressione CTRL+SHIFT+R (hard refresh) para limpar cache
-- 4. OU feche e abra uma nova aba
-- 5. Faça login novamente se necessário
-- 6. As métricas DEVEM aparecer!
-- ===================================================================

