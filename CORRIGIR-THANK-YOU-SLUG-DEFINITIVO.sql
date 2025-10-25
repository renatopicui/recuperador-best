-- ===================================================================
-- 🔧 CORRIGIR THANK YOU SLUG - SÓ CRIAR QUANDO PAGO
-- ===================================================================
-- Remove trigger antigo que cria slug na criação
-- Mantém apenas trigger que cria quando pagamento é confirmado
-- ===================================================================

-- PASSO 1: Ver situação atual
SELECT '🔍 SITUAÇÃO ATUAL' as status;

SELECT 
    cl.checkout_slug,
    cl.payment_status,
    cl.thank_you_slug,
    p.status as payment_real_status,
    CASE 
        WHEN cl.thank_you_slug IS NOT NULL AND p.status != 'paid' 
        THEN '❌ PROBLEMA: Tem slug mas não está pago'
        WHEN cl.thank_you_slug IS NOT NULL AND p.status = 'paid' 
        THEN '✅ OK: Tem slug e está pago'
        WHEN cl.thank_you_slug IS NULL AND p.status = 'paid'
        THEN '⚠️ PRECISA GERAR: Está pago mas sem slug'
        ELSE '✅ OK: Pendente sem slug'
    END as diagnostico
FROM checkout_links cl
LEFT JOIN payments p ON cl.payment_id = p.id
ORDER BY cl.created_at DESC
LIMIT 20;

-- ===================================================================
-- PASSO 2: REMOVER TRIGGER ANTIGO PROBLEMÁTICO
-- ===================================================================

SELECT '🧹 REMOVENDO TRIGGER ANTIGO...' as status;

-- Remover trigger que cria na inserção
DROP TRIGGER IF EXISTS trigger_generate_thank_you_slug ON checkout_links;
DROP TRIGGER IF EXISTS auto_generate_thank_you_slug ON checkout_links;
DROP FUNCTION IF EXISTS auto_generate_thank_you_slug() CASCADE;

SELECT '✅ Trigger antigo removido!' as status;

-- ===================================================================
-- PASSO 3: LIMPAR thank_you_slug DE CHECKOUTS NÃO PAGOS
-- ===================================================================

SELECT '🧹 LIMPANDO SLUGS DE CHECKOUTS NÃO PAGOS...' as status;

UPDATE checkout_links cl
SET thank_you_slug = NULL
FROM payments p
WHERE cl.payment_id = p.id
AND p.status != 'paid'
AND cl.thank_you_slug IS NOT NULL;

SELECT '✅ Slugs limpos!' as status;

-- ===================================================================
-- PASSO 4: GARANTIR QUE FUNÇÃO DE GERAÇÃO EXISTE
-- ===================================================================

SELECT '🔧 CRIANDO FUNÇÃO DE GERAÇÃO...' as status;

CREATE OR REPLACE FUNCTION generate_unique_thank_you_slug()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    new_slug TEXT;
    slug_exists BOOLEAN;
BEGIN
    LOOP
        new_slug := 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12);
        SELECT EXISTS(SELECT 1 FROM checkout_links WHERE thank_you_slug = new_slug) INTO slug_exists;
        EXIT WHEN NOT slug_exists;
    END LOOP;
    RETURN new_slug;
END;
$$;

SELECT '✅ Função de geração criada!' as status;

-- ===================================================================
-- PASSO 5: CRIAR TRIGGER CORRETO (SÓ QUANDO PAGO)
-- ===================================================================

SELECT '⚡ CRIANDO TRIGGER CORRETO...' as status;

-- Remover se já existe
DROP TRIGGER IF EXISTS generate_thank_you_slug_on_payment ON payments;
DROP FUNCTION IF EXISTS generate_thank_you_slug_on_payment() CASCADE;

-- Criar função do trigger
CREATE OR REPLACE FUNCTION generate_thank_you_slug_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_checkout_id UUID;
    v_existing_slug TEXT;
    v_new_slug TEXT;
BEGIN
    -- SÓ EXECUTAR se status mudou para 'paid'
    IF NEW.status = 'paid' AND (OLD IS NULL OR OLD.status != 'paid') THEN
        
        RAISE NOTICE '🎉 [TRIGGER] Pagamento confirmado! Payment ID: %', NEW.id;
        
        -- Buscar checkout relacionado
        SELECT id, thank_you_slug INTO v_checkout_id, v_existing_slug
        FROM checkout_links
        WHERE payment_id = NEW.id;
        
        IF v_checkout_id IS NOT NULL THEN
            -- Se JÁ TEM slug, não fazer nada
            IF v_existing_slug IS NOT NULL THEN
                RAISE NOTICE '✓ [TRIGGER] Thank you slug já existe: %', v_existing_slug;
            ELSE
                -- GERAR NOVO slug
                v_new_slug := generate_unique_thank_you_slug();
                
                -- Atualizar checkout
                UPDATE checkout_links
                SET thank_you_slug = v_new_slug
                WHERE id = v_checkout_id;
                
                RAISE NOTICE '✅ [TRIGGER] Thank you slug gerado: %', v_new_slug;
            END IF;
        ELSE
            RAISE NOTICE '⚠️ [TRIGGER] Nenhum checkout encontrado para payment: %', NEW.id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Criar trigger
CREATE TRIGGER generate_thank_you_slug_on_payment
AFTER INSERT OR UPDATE OF status ON payments
FOR EACH ROW
EXECUTE FUNCTION generate_thank_you_slug_on_payment();

SELECT '✅ Trigger correto criado!' as status;

-- ===================================================================
-- PASSO 6: GERAR SLUGS PARA PAGAMENTOS JÁ PAGOS (retroativo)
-- ===================================================================

SELECT '🔄 GERANDO SLUGS PARA PAGAMENTOS JÁ PAGOS...' as status;

DO $$
DECLARE
    payment_record RECORD;
    new_slug TEXT;
    affected_count INT := 0;
BEGIN
    FOR payment_record IN 
        SELECT 
            p.id as payment_id,
            cl.id as checkout_id,
            cl.checkout_slug
        FROM payments p
        INNER JOIN checkout_links cl ON p.id = cl.payment_id
        WHERE p.status = 'paid'
        AND cl.thank_you_slug IS NULL
    LOOP
        new_slug := generate_unique_thank_you_slug();
        
        UPDATE checkout_links
        SET thank_you_slug = new_slug
        WHERE id = payment_record.checkout_id;
        
        affected_count := affected_count + 1;
        RAISE NOTICE '✅ Slug gerado: % para checkout: %', new_slug, payment_record.checkout_slug;
    END LOOP;
    
    RAISE NOTICE '📊 Total de slugs gerados retroativamente: %', affected_count;
END $$;

SELECT '✅ Slugs retroativos gerados!' as status;

-- ===================================================================
-- PASSO 7: VERIFICAÇÃO FINAL
-- ===================================================================

SELECT '📊 VERIFICAÇÃO FINAL' as status;

-- Ver todos os triggers ativos
SELECT 
    '⚡ TRIGGERS ATIVOS' as tipo,
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers
WHERE event_object_table IN ('checkout_links', 'payments')
AND trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- Ver situação dos checkouts
SELECT 
    '📋 SITUAÇÃO APÓS CORREÇÃO' as tipo,
    cl.checkout_slug,
    cl.payment_status,
    cl.thank_you_slug,
    p.status as payment_real_status,
    CASE 
        WHEN cl.thank_you_slug IS NOT NULL AND p.status = 'paid' 
        THEN '✅ CORRETO'
        WHEN cl.thank_you_slug IS NULL AND p.status != 'paid'
        THEN '✅ CORRETO'
        WHEN cl.thank_you_slug IS NOT NULL AND p.status != 'paid'
        THEN '❌ PROBLEMA'
        WHEN cl.thank_you_slug IS NULL AND p.status = 'paid'
        THEN '⚠️ FALTA SLUG'
        ELSE '?' 
    END as status_final
FROM checkout_links cl
LEFT JOIN payments p ON cl.payment_id = p.id
ORDER BY cl.created_at DESC
LIMIT 20;

-- Estatísticas
SELECT 
    '📊 ESTATÍSTICAS' as tipo,
    COUNT(*) as total_checkouts,
    SUM(CASE WHEN thank_you_slug IS NOT NULL THEN 1 ELSE 0 END) as com_slug,
    SUM(CASE WHEN thank_you_slug IS NULL THEN 1 ELSE 0 END) as sem_slug,
    SUM(CASE WHEN payment_status = 'paid' AND thank_you_slug IS NOT NULL THEN 1 ELSE 0 END) as pagos_com_slug,
    SUM(CASE WHEN payment_status = 'paid' AND thank_you_slug IS NULL THEN 1 ELSE 0 END) as pagos_sem_slug,
    SUM(CASE WHEN payment_status != 'paid' AND thank_you_slug IS NOT NULL THEN 1 ELSE 0 END) as pendentes_com_slug,
    SUM(CASE WHEN payment_status != 'paid' AND thank_you_slug IS NULL THEN 1 ELSE 0 END) as pendentes_sem_slug
FROM checkout_links;

-- ===================================================================
-- ✅ PRONTO! AGORA:
-- ===================================================================
-- 1. ✅ Trigger antigo removido (que criava na inserção)
-- 2. ✅ Slugs limpos de checkouts não pagos
-- 3. ✅ Trigger correto instalado (só cria quando pago)
-- 4. ✅ Slugs gerados para pagamentos já pagos
--
-- RESULTADO ESPERADO:
-- - Checkouts NÃO pagos: thank_you_slug = NULL ✅
-- - Checkouts PAGOS: thank_you_slug = 'ty-xxx' ✅
--
-- TESTE:
-- 1. Crie novo checkout
-- 2. Verifique: thank_you_slug = NULL ✅
-- 3. Pague o checkout
-- 4. Verifique: thank_you_slug gerado automaticamente ✅
-- 5. Redirecionamento funciona! ✅
-- ===================================================================

