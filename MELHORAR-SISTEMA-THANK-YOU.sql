-- ===================================================================
-- 🎯 MELHORAR SISTEMA DE THANK YOU PAGE
-- ===================================================================
-- Gerar thank_you_slug APENAS quando pagamento for confirmado
-- ===================================================================

-- PASSO 1: Remover thank_you_slug de checkouts não pagos
UPDATE checkout_links cl
SET thank_you_slug = NULL
FROM payments p
WHERE cl.payment_id = p.id
AND p.status != 'paid'
AND cl.thank_you_slug IS NOT NULL;

-- PASSO 2: Criar função para gerar thank_you_slug único
CREATE OR REPLACE FUNCTION generate_unique_thank_you_slug()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    new_slug TEXT;
    slug_exists BOOLEAN;
BEGIN
    LOOP
        -- Gerar slug único
        new_slug := 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12);
        
        -- Verificar se já existe
        SELECT EXISTS(
            SELECT 1 FROM checkout_links WHERE thank_you_slug = new_slug
        ) INTO slug_exists;
        
        EXIT WHEN NOT slug_exists;
    END LOOP;
    
    RETURN new_slug;
END;
$$;

-- PASSO 3: Criar TRIGGER que gera thank_you_slug quando pagamento for confirmado
DROP TRIGGER IF EXISTS generate_thank_you_slug_on_payment ON payments;
DROP FUNCTION IF EXISTS generate_thank_you_slug_on_payment();

CREATE OR REPLACE FUNCTION generate_thank_you_slug_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_checkout_id UUID;
    v_existing_slug TEXT;
    v_new_slug TEXT;
BEGIN
    -- Só gerar se o status mudou para 'paid'
    IF NEW.status = 'paid' AND (OLD.status IS NULL OR OLD.status != 'paid') THEN
        
        RAISE NOTICE '🎉 [TRIGGER] Pagamento confirmado! Payment ID: %, Bestfy ID: %', NEW.id, NEW.bestfy_id;
        
        -- Buscar checkout relacionado
        SELECT id, thank_you_slug INTO v_checkout_id, v_existing_slug
        FROM checkout_links
        WHERE payment_id = NEW.id;
        
        IF v_checkout_id IS NOT NULL THEN
            -- Se já tem slug, não gerar novo
            IF v_existing_slug IS NOT NULL THEN
                RAISE NOTICE '✓ [TRIGGER] Thank you slug já existe: %', v_existing_slug;
            ELSE
                -- Gerar novo slug
                v_new_slug := generate_unique_thank_you_slug();
                
                -- Atualizar checkout com o slug
                UPDATE checkout_links
                SET thank_you_slug = v_new_slug
                WHERE id = v_checkout_id;
                
                RAISE NOTICE '✅ [TRIGGER] Thank you slug gerado: % para checkout: %', v_new_slug, v_checkout_id;
            END IF;
        ELSE
            RAISE NOTICE '⚠️ [TRIGGER] Nenhum checkout encontrado para payment: %', NEW.id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER generate_thank_you_slug_on_payment
AFTER INSERT OR UPDATE OF status ON payments
FOR EACH ROW
EXECUTE FUNCTION generate_thank_you_slug_on_payment();

-- PASSO 4: Gerar thank_you_slug para pagamentos já confirmados (retroativo)
DO $$
DECLARE
    payment_record RECORD;
    new_slug TEXT;
BEGIN
    FOR payment_record IN 
        SELECT 
            p.id as payment_id,
            cl.id as checkout_id,
            cl.thank_you_slug,
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
        
        RAISE NOTICE '✅ Slug retroativo gerado: % para checkout: %', new_slug, payment_record.checkout_slug;
    END LOOP;
END $$;

-- PASSO 5: Verificar resultado
SELECT 
    '📊 ESTATÍSTICAS' as titulo,
    COUNT(*) as total_checkouts,
    SUM(CASE WHEN thank_you_slug IS NOT NULL THEN 1 ELSE 0 END) as com_thank_you_slug,
    SUM(CASE WHEN thank_you_slug IS NULL THEN 1 ELSE 0 END) as sem_thank_you_slug,
    SUM(CASE WHEN payment_status = 'paid' AND thank_you_slug IS NOT NULL THEN 1 ELSE 0 END) as pagos_com_slug,
    SUM(CASE WHEN payment_status = 'paid' AND thank_you_slug IS NULL THEN 1 ELSE 0 END) as pagos_sem_slug
FROM checkout_links;

-- PASSO 6: Listar checkouts e seus status
SELECT 
    '📋 CHECKOUTS' as titulo,
    cl.checkout_slug,
    cl.payment_status,
    cl.thank_you_slug,
    p.status as payment_real_status,
    CASE 
        WHEN p.status = 'paid' AND cl.thank_you_slug IS NOT NULL THEN '✅ OK - Pago com slug'
        WHEN p.status = 'paid' AND cl.thank_you_slug IS NULL THEN '⚠️ PROBLEMA - Pago sem slug'
        WHEN p.status != 'paid' AND cl.thank_you_slug IS NULL THEN '✅ OK - Pendente sem slug'
        WHEN p.status != 'paid' AND cl.thank_you_slug IS NOT NULL THEN '🧹 LIMPO - Era slug desnecessário'
    END as status_slug
FROM checkout_links cl
LEFT JOIN payments p ON cl.payment_id = p.id
ORDER BY cl.created_at DESC
LIMIT 20;

-- ===================================================================
-- 🎯 COMO FUNCIONA AGORA:
-- ===================================================================
-- 1. Checkout criado → SEM thank_you_slug ✅
-- 2. Cliente paga → Webhook atualiza payment.status = 'paid'
-- 3. TRIGGER detecta → Gera thank_you_slug automaticamente ✅
-- 4. Frontend polling → Detecta status = 'paid' + thank_you_slug
-- 5. Redireciona → /obrigado/{thank_you_slug} ✅
-- 6. Marca como recuperado ✅
-- 
-- BENEFÍCIOS:
-- ✅ Não desperdiça slugs em pagamentos não concluídos
-- ✅ Mais eficiente e limpo
-- ✅ Geração automática via trigger (sem código extra)
-- ✅ Mantém toda a lógica de redirecionamento igual
-- ===================================================================

