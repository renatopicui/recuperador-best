-- ===================================================================
-- 🔥 SOLUÇÃO COMPLETA FINAL - EXECUTE NO SUPABASE SQL EDITOR
-- ===================================================================
-- Este script resolve TUDO de uma vez por todas
-- ===================================================================

-- PASSO 1: Adicionar colunas necessárias
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' AND column_name = 'thank_you_slug'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_slug TEXT;
        RAISE NOTICE '✅ Coluna thank_you_slug adicionada';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' AND column_name = 'thank_you_accessed_at'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_accessed_at TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE '✅ Coluna thank_you_accessed_at adicionada';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' AND column_name = 'thank_you_access_count'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_access_count INTEGER DEFAULT 0;
        RAISE NOTICE '✅ Coluna thank_you_access_count adicionada';
    END IF;

    -- Adicionar payment_status se não existir (para o webhook funcionar)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' AND column_name = 'payment_status'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN payment_status TEXT DEFAULT 'waiting_payment';
        RAISE NOTICE '✅ Coluna payment_status adicionada';
    END IF;
END $$;

-- PASSO 2: Criar índice único
CREATE UNIQUE INDEX IF NOT EXISTS idx_checkout_links_thank_you_slug 
ON checkout_links(thank_you_slug);

-- PASSO 3: Gerar thank_you_slug para TODOS os checkouts existentes
UPDATE checkout_links
SET thank_you_slug = 'ty-' || substr(md5(random()::text || id::text), 1, 12)
WHERE thank_you_slug IS NULL;

-- PASSO 4: Sincronizar payment_status com tabela payments
UPDATE checkout_links cl
SET payment_status = p.status
FROM payments p
WHERE cl.payment_id = p.id
AND (cl.payment_status IS NULL OR cl.payment_status != p.status);

-- PASSO 5: Criar função get_checkout_by_slug DEFINITIVA
DROP FUNCTION IF EXISTS get_checkout_by_slug(TEXT);

CREATE OR REPLACE FUNCTION get_checkout_by_slug(p_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'id', cl.id,
        'checkout_slug', cl.checkout_slug,
        'thank_you_slug', cl.thank_you_slug,
        'payment_id', cl.payment_id,
        'customer_name', cl.customer_name,
        'customer_email', cl.customer_email,
        'customer_document', cl.customer_document,
        'amount', cl.amount,
        'final_amount', cl.final_amount,
        'status', cl.status,
        'payment_status', COALESCE(p.status, cl.payment_status, 'waiting_payment'),
        'payment_bestfy_id', p.bestfy_id,
        'product_name', p.product_name,
        'pix_qrcode', cl.pix_qrcode,
        'pix_expires_at', cl.pix_expires_at,
        'expires_at', cl.expires_at
    )
    INTO result
    FROM checkout_links cl
    LEFT JOIN payments p ON cl.payment_id = p.id
    WHERE cl.checkout_slug = p_slug;
    
    RETURN result;
END;
$$;

-- PASSO 6: Criar função access_thank_you_page
DROP FUNCTION IF EXISTS access_thank_you_page(TEXT);

CREATE OR REPLACE FUNCTION access_thank_you_page(p_thank_you_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_checkout_id UUID;
    v_payment_id UUID;
BEGIN
    SELECT id, payment_id INTO v_checkout_id, v_payment_id
    FROM checkout_links
    WHERE thank_you_slug = p_thank_you_slug;
    
    IF v_checkout_id IS NULL THEN
        RAISE EXCEPTION 'Página não encontrada';
    END IF;
    
    UPDATE checkout_links
    SET 
        thank_you_accessed_at = NOW(),
        thank_you_access_count = COALESCE(thank_you_access_count, 0) + 1
    WHERE id = v_checkout_id;
    
    UPDATE payments
    SET 
        converted_from_recovery = TRUE,
        recovered_at = COALESCE(recovered_at, NOW())
    WHERE id = v_payment_id AND status = 'paid';
    
    RETURN jsonb_build_object('success', true);
END;
$$;

-- PASSO 7: Criar função get_thank_you_page
DROP FUNCTION IF EXISTS get_thank_you_page(TEXT);

CREATE OR REPLACE FUNCTION get_thank_you_page(p_thank_you_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'thank_you_slug', cl.thank_you_slug,
        'checkout_slug', cl.checkout_slug,
        'customer_name', cl.customer_name,
        'customer_email', cl.customer_email,
        'product_name', p.product_name,
        'amount', cl.amount,
        'final_amount', cl.final_amount,
        'payment_status', p.status,
        'payment_bestfy_id', p.bestfy_id
    )
    INTO result
    FROM checkout_links cl
    INNER JOIN payments p ON cl.payment_id = p.id
    WHERE cl.thank_you_slug = p_thank_you_slug;
    
    IF result IS NULL THEN
        RAISE EXCEPTION 'Página não encontrada';
    END IF;
    
    RETURN result;
END;
$$;

-- PASSO 8: Criar trigger para sincronizar automaticamente o payment_status
DROP TRIGGER IF EXISTS sync_payment_status_to_checkout ON payments;
DROP FUNCTION IF EXISTS sync_payment_status_to_checkout();

CREATE OR REPLACE FUNCTION sync_payment_status_to_checkout()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Atualizar checkout_links quando payment.status mudar
    UPDATE checkout_links
    SET payment_status = NEW.status
    WHERE payment_id = NEW.id;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER sync_payment_status_to_checkout
AFTER INSERT OR UPDATE OF status ON payments
FOR EACH ROW
EXECUTE FUNCTION sync_payment_status_to_checkout();

-- ===================================================================
-- ✅ VERIFICAÇÃO FINAL
-- ===================================================================
SELECT 
    '✅ CHECKOUTS VERIFICADOS' as titulo,
    cl.checkout_slug,
    cl.status as checkout_status,
    cl.payment_status,
    cl.thank_you_slug,
    p.status as payment_real_status,
    CASE 
        WHEN cl.thank_you_slug IS NOT NULL AND p.status = 'paid' THEN '✅ PRONTO PARA REDIRECIONAR'
        WHEN cl.thank_you_slug IS NOT NULL AND p.status != 'paid' THEN '⏳ AGUARDANDO PAGAMENTO'
        WHEN cl.thank_you_slug IS NULL THEN '❌ FALTA SLUG'
        ELSE '⚠️ VERIFICAR'
    END as resultado
FROM checkout_links cl
LEFT JOIN payments p ON cl.payment_id = p.id
WHERE cl.checkout_slug IN ('7huoo30x', '9mj9dmyq', 'y2ji98vb')
ORDER BY cl.created_at DESC;

-- ===================================================================
-- 📊 RESUMO DO QUE FOI FEITO
-- ===================================================================
SELECT 
    '📊 ESTATÍSTICAS' as titulo,
    COUNT(*) as total_checkouts,
    COUNT(thank_you_slug) as com_thank_you_slug,
    SUM(CASE WHEN payment_status = 'paid' THEN 1 ELSE 0 END) as pagos,
    SUM(CASE WHEN payment_status = 'paid' AND thank_you_slug IS NOT NULL THEN 1 ELSE 0 END) as prontos_para_redirecionar
FROM checkout_links;

-- ===================================================================
-- 🎯 PRONTO! AGORA FUNCIONA ASSIM:
-- ===================================================================
-- 1. Webhook Bestfy confirma pagamento
-- 2. payments.status = 'paid'
-- 3. TRIGGER atualiza checkout_links.payment_status = 'paid' automaticamente
-- 4. Frontend polling detecta payment_status = 'paid'
-- 5. Frontend pega thank_you_slug
-- 6. Redireciona para /obrigado/{thank_you_slug}
-- 7. Marca como recuperado automaticamente
-- ===================================================================

