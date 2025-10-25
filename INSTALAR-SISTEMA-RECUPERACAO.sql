-- ===================================================================
-- 🔥 INSTALAR SISTEMA DE RECUPERAÇÃO - EXECUTE NO SUPABASE SQL EDITOR
-- ===================================================================
-- Este script instala o sistema completo de recuperação automática
-- ===================================================================

-- PASSO 1: Adicionar colunas necessárias (se não existirem)
DO $$ 
BEGIN
    -- thank_you_slug
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' AND column_name = 'thank_you_slug'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_slug TEXT;
        CREATE UNIQUE INDEX idx_checkout_links_thank_you_slug ON checkout_links(thank_you_slug);
        RAISE NOTICE '✅ Coluna thank_you_slug adicionada';
    ELSE
        RAISE NOTICE '✓ Coluna thank_you_slug já existe';
    END IF;
    
    -- thank_you_accessed_at
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' AND column_name = 'thank_you_accessed_at'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_accessed_at TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE '✅ Coluna thank_you_accessed_at adicionada';
    ELSE
        RAISE NOTICE '✓ Coluna thank_you_accessed_at já existe';
    END IF;
    
    -- thank_you_access_count
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' AND column_name = 'thank_you_access_count'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_access_count INTEGER DEFAULT 0;
        RAISE NOTICE '✅ Coluna thank_you_access_count adicionada';
    ELSE
        RAISE NOTICE '✓ Coluna thank_you_access_count já existe';
    END IF;
END $$;

-- PASSO 2: Gerar thank_you_slug para TODOS os checkouts que não têm
UPDATE checkout_links
SET thank_you_slug = 'ty-' || substr(md5(random()::text || id::text || NOW()::text), 1, 12)
WHERE thank_you_slug IS NULL;

-- PASSO 3: Criar função get_checkout_by_slug
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
        'payment_status', cl.payment_status,
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

-- PASSO 4: Criar função access_thank_you_page
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
    WHERE id = v_payment_id 
    AND status = 'paid'
    AND (converted_from_recovery IS NULL OR converted_from_recovery = FALSE);
    
    RETURN jsonb_build_object('success', true);
END;
$$;

-- PASSO 5: Criar função get_thank_you_page
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
        'payment_status', cl.payment_status,
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

-- ===================================================================
-- ✅ VERIFICAÇÃO DOS CHECKOUTS
-- ===================================================================
SELECT 
    '✅ VERIFICAÇÃO' as titulo,
    checkout_slug,
    payment_status,
    thank_you_slug,
    CASE 
        WHEN thank_you_slug IS NOT NULL AND payment_status = 'paid' THEN '✅ PRONTO - VAI REDIRECIONAR'
        WHEN thank_you_slug IS NOT NULL AND payment_status != 'paid' THEN '⏳ AGUARDANDO PAGAMENTO'
        WHEN thank_you_slug IS NULL THEN '❌ FALTA SLUG'
        ELSE '⚠️ VERIFICAR'
    END as resultado
FROM checkout_links
WHERE checkout_slug IN ('7huoo30x', '9mj9dmyq', 'y2ji98vb')
ORDER BY created_at DESC;

-- ===================================================================
-- 🎯 SISTEMA INSTALADO! AGORA FUNCIONA ASSIM:
-- ===================================================================
-- 1. Webhook Bestfy atualiza checkout_links.payment_status = 'paid' ✅
-- 2. Frontend polling detecta payment_status = 'paid' ✅
-- 3. Frontend pega thank_you_slug ✅
-- 4. Redireciona para /obrigado/{thank_you_slug} ✅
-- 5. Página de obrigado marca como recuperado ✅
-- 6. Dashboard mostra estatísticas ✅
-- ===================================================================

