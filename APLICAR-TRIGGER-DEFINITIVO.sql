-- ===================================================================
-- 🚀 APLICAR TRIGGER DEFINITIVO - GERAR THANK YOU SLUG QUANDO PAGO
-- ===================================================================
-- Cria triggers em AMBAS as tabelas (payments e checkout_links)
-- Garante que funcione independente de qual campo o webhook atualiza
-- ===================================================================

-- PASSO 1: Verificar situação atual
SELECT '🔍 VERIFICANDO TRANSAÇÃO ozxjiphf...' as status;

SELECT 
    cl.checkout_slug,
    cl.payment_status,
    p.status as payment_status_real,
    cl.thank_you_slug,
    CASE 
        WHEN cl.thank_you_slug IS NULL AND (cl.payment_status = 'paid' OR p.status = 'paid')
        THEN '⚠️ PAGO MAS SEM SLUG - PRECISA GERAR!'
        WHEN cl.thank_you_slug IS NOT NULL
        THEN '✅ JÁ TEM SLUG'
        ELSE '⏳ AGUARDANDO PAGAMENTO'
    END as situacao
FROM checkout_links cl
LEFT JOIN payments p ON cl.payment_id = p.id
WHERE cl.checkout_slug = 'ozxjiphf';

-- ===================================================================
-- PASSO 2: REMOVER TRIGGERS ANTIGOS
-- ===================================================================

SELECT '🧹 REMOVENDO TRIGGERS ANTIGOS...' as status;

-- Remover triggers antigos de checkout_links
DROP TRIGGER IF EXISTS trigger_generate_thank_you_slug ON checkout_links;
DROP TRIGGER IF EXISTS auto_generate_thank_you_slug ON checkout_links;
DROP TRIGGER IF EXISTS generate_thank_you_on_checkout_paid ON checkout_links;

-- Remover triggers antigos de payments
DROP TRIGGER IF EXISTS generate_thank_you_slug_on_payment ON payments;
DROP TRIGGER IF EXISTS generate_thank_you_on_payment_paid ON payments;

-- Remover funções antigas
DROP FUNCTION IF EXISTS auto_generate_thank_you_slug() CASCADE;
DROP FUNCTION IF EXISTS generate_thank_you_slug_on_payment() CASCADE;
DROP FUNCTION IF EXISTS generate_thank_you_on_paid() CASCADE;

SELECT '✅ Triggers antigos removidos!' as status;

-- ===================================================================
-- PASSO 3: CRIAR FUNÇÃO DE GERAÇÃO DE SLUG
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

SELECT '✅ Função criada!' as status;

-- ===================================================================
-- PASSO 4: CRIAR TRIGGER PARA payments.status
-- ===================================================================

SELECT '⚡ CRIANDO TRIGGER PARA payments.status...' as status;

CREATE OR REPLACE FUNCTION generate_thank_you_on_payment_paid()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_checkout_id UUID;
    v_existing_slug TEXT;
    v_new_slug TEXT;
BEGIN
    -- Só executar se mudou para 'paid'
    IF NEW.status = 'paid' AND (OLD IS NULL OR OLD.status != 'paid') THEN
        
        RAISE NOTICE '🎉 [payments.status] Pagamento confirmado! Payment ID: %', NEW.id;
        
        -- Buscar checkout
        SELECT id, thank_you_slug INTO v_checkout_id, v_existing_slug
        FROM checkout_links
        WHERE payment_id = NEW.id;
        
        IF v_checkout_id IS NOT NULL AND v_existing_slug IS NULL THEN
            -- Gerar slug
            v_new_slug := generate_unique_thank_you_slug();
            
            -- Atualizar checkout
            UPDATE checkout_links
            SET thank_you_slug = v_new_slug
            WHERE id = v_checkout_id;
            
            RAISE NOTICE '✅ [payments.status] Thank you slug gerado: %', v_new_slug;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER generate_thank_you_on_payment_paid
AFTER INSERT OR UPDATE OF status ON payments
FOR EACH ROW
EXECUTE FUNCTION generate_thank_you_on_payment_paid();

SELECT '✅ Trigger para payments.status criado!' as status;

-- ===================================================================
-- PASSO 5: CRIAR TRIGGER PARA checkout_links.payment_status
-- ===================================================================

SELECT '⚡ CRIANDO TRIGGER PARA checkout_links.payment_status...' as status;

CREATE OR REPLACE FUNCTION generate_thank_you_on_checkout_paid()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_slug TEXT;
BEGIN
    -- Só executar se mudou para 'paid'
    IF NEW.payment_status = 'paid' AND (OLD IS NULL OR OLD.payment_status != 'paid') THEN
        
        -- Se já tem slug, não fazer nada
        IF NEW.thank_you_slug IS NULL THEN
            RAISE NOTICE '🎉 [checkout_links.payment_status] Pagamento confirmado! Checkout: %', NEW.checkout_slug;
            
            -- Gerar slug
            v_new_slug := generate_unique_thank_you_slug();
            
            -- Atualizar direto no NEW para usar no UPDATE
            NEW.thank_you_slug := v_new_slug;
            
            RAISE NOTICE '✅ [checkout_links.payment_status] Thank you slug gerado: %', v_new_slug;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER generate_thank_you_on_checkout_paid
BEFORE UPDATE OF payment_status ON checkout_links
FOR EACH ROW
EXECUTE FUNCTION generate_thank_you_on_checkout_paid();

SELECT '✅ Trigger para checkout_links.payment_status criado!' as status;

-- ===================================================================
-- PASSO 6: GERAR SLUGS RETROATIVOS (para já pagos)
-- ===================================================================

SELECT '🔄 GERANDO SLUGS PARA TRANSAÇÕES JÁ PAGAS...' as status;

DO $$
DECLARE
    checkout_record RECORD;
    new_slug TEXT;
    affected_count INT := 0;
BEGIN
    -- Buscar checkouts pagos sem slug
    FOR checkout_record IN 
        SELECT 
            cl.id as checkout_id,
            cl.checkout_slug,
            cl.payment_status,
            p.status as payment_real_status
        FROM checkout_links cl
        LEFT JOIN payments p ON cl.payment_id = p.id
        WHERE (cl.payment_status = 'paid' OR p.status = 'paid')
        AND cl.thank_you_slug IS NULL
    LOOP
        -- Gerar slug
        new_slug := generate_unique_thank_you_slug();
        
        -- Atualizar checkout
        UPDATE checkout_links
        SET thank_you_slug = new_slug
        WHERE id = checkout_record.checkout_id;
        
        affected_count := affected_count + 1;
        RAISE NOTICE '✅ Slug gerado: % para checkout: %', new_slug, checkout_record.checkout_slug;
    END LOOP;
    
    RAISE NOTICE '📊 Total de slugs gerados: %', affected_count;
END $$;

SELECT '✅ Slugs retroativos gerados!' as status;

-- ===================================================================
-- PASSO 7: VERIFICAÇÃO FINAL
-- ===================================================================

SELECT '📊 VERIFICAÇÃO FINAL' as status;

-- Ver triggers ativos
SELECT 
    'TRIGGERS ATIVOS' as tipo,
    trigger_name,
    event_object_table as tabela,
    event_manipulation as evento
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND event_object_table IN ('checkout_links', 'payments')
AND trigger_name LIKE '%thank_you%'
ORDER BY event_object_table;

-- Ver situação da transação ozxjiphf
SELECT 
    'TRANSAÇÃO ozxjiphf' as tipo,
    cl.checkout_slug,
    cl.payment_status,
    p.status as payment_real_status,
    cl.thank_you_slug,
    CASE 
        WHEN cl.thank_you_slug IS NOT NULL
        THEN '✅ PRONTO PARA REDIRECIONAR!'
        ELSE '❌ PROBLEMA'
    END as status_final
FROM checkout_links cl
LEFT JOIN payments p ON cl.payment_id = p.id
WHERE cl.checkout_slug = 'ozxjiphf';

-- Estatísticas gerais
SELECT 
    'ESTATÍSTICAS' as tipo,
    COUNT(*) as total,
    SUM(CASE WHEN payment_status = 'paid' THEN 1 ELSE 0 END) as pagos,
    SUM(CASE WHEN payment_status = 'paid' AND thank_you_slug IS NOT NULL THEN 1 ELSE 0 END) as pagos_com_slug,
    SUM(CASE WHEN payment_status = 'paid' AND thank_you_slug IS NULL THEN 1 ELSE 0 END) as pagos_sem_slug
FROM checkout_links;

-- ===================================================================
-- ✅ PRONTO!
-- ===================================================================
-- TRIGGERS CRIADOS:
-- 1. ✅ generate_thank_you_on_payment_paid (payments.status)
-- 2. ✅ generate_thank_you_on_checkout_paid (checkout_links.payment_status)
--
-- FUNCIONAMENTO:
-- - Quando webhook atualiza qualquer campo para 'paid'
-- - Trigger gera thank_you_slug automaticamente
-- - Frontend detecta e redireciona
--
-- PRÓXIMO PASSO:
-- 1. Acesse: http://localhost:5173/checkout/ozxjiphf
-- 2. Verifique se redireciona para /obrigado/ty-xxx
-- 3. Se não redirecionar, recarregue a página (Ctrl+R)
-- ===================================================================

