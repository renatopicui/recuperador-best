-- ===================================================================
-- 🔥 SOLUÇÃO DEFINITIVA - EXECUTE NO SUPABASE SQL EDITOR
-- ===================================================================
-- Este é o script mais simples possível que vai funcionar
-- ===================================================================

-- 1. Adicionar coluna thank_you_slug se não existir
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' AND column_name = 'thank_you_slug'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_slug TEXT;
        CREATE UNIQUE INDEX IF NOT EXISTS idx_checkout_links_thank_you_slug ON checkout_links(thank_you_slug);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' AND column_name = 'thank_you_accessed_at'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_accessed_at TIMESTAMP WITH TIME ZONE;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' AND column_name = 'thank_you_access_count'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_access_count INTEGER DEFAULT 0;
    END IF;
END $$;

-- 2. Gerar thank_you_slug para TODOS os checkouts (inclusive os que já existem)
UPDATE checkout_links
SET thank_you_slug = 'ty-' || substr(md5(random()::text || id::text || checkout_slug::text), 1, 12)
WHERE thank_you_slug IS NULL;

-- 3. Função SIMPLES get_checkout_by_slug - SÓ COM CAMPOS QUE EXISTEM
DROP FUNCTION IF EXISTS get_checkout_by_slug(TEXT);

CREATE OR REPLACE FUNCTION get_checkout_by_slug(p_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    -- Buscar dados (SEM incrementar access_count para evitar problemas)
    SELECT jsonb_build_object(
        'id', cl.id,
        'checkout_slug', cl.checkout_slug,
        'thank_you_slug', cl.thank_you_slug,
        'payment_id', cl.payment_id,
        'customer_name', cl.customer_name,
        'customer_email', cl.customer_email,
        'customer_document', cl.customer_document,
        'product_name', p.product_name,
        'amount', cl.amount,
        'final_amount', cl.final_amount,
        'status', cl.status,
        'payment_status', p.status,
        'payment_bestfy_id', p.bestfy_id,
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

-- 4. Função para página de obrigado
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
    
    -- Marcar como recuperado
    UPDATE payments
    SET 
        converted_from_recovery = TRUE,
        recovered_at = COALESCE(recovered_at, NOW())
    WHERE id = v_payment_id AND status = 'paid';
    
    RETURN jsonb_build_object('success', true);
END;
$$;

-- 5. Função para buscar dados da página de obrigado
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
    
    RETURN result;
END;
$$;

-- ===================================================================
-- ✅ VERIFICAR RESULTADOS
-- ===================================================================
SELECT 
    checkout_slug,
    status,
    thank_you_slug,
    CASE 
        WHEN thank_you_slug IS NOT NULL THEN '✅ TEM SLUG - VAI FUNCIONAR'
        ELSE '❌ SEM SLUG - NÃO VAI FUNCIONAR'
    END as resultado
FROM checkout_links
WHERE checkout_slug IN ('7huoo30x', '9mj9dmyq')
ORDER BY created_at DESC;

