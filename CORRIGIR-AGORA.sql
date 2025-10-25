-- ===================================================================
-- 🔥 CORRIGIR AGORA - EXECUTAR NO SQL EDITOR DO SUPABASE
-- ===================================================================
-- Este script corrige os erros de colunas inexistentes
-- ===================================================================

-- 1. Adicionar colunas que faltam (se não existirem)
ALTER TABLE checkout_links ADD COLUMN IF NOT EXISTS thank_you_slug TEXT UNIQUE;
ALTER TABLE checkout_links ADD COLUMN IF NOT EXISTS thank_you_accessed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE checkout_links ADD COLUMN IF NOT EXISTS thank_you_access_count INTEGER DEFAULT 0;

-- 2. Criar função para gerar thank_you_slug
CREATE OR REPLACE FUNCTION generate_thank_you_slug(p_checkout_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_slug TEXT;
    v_exists BOOLEAN;
BEGIN
    SELECT thank_you_slug INTO v_slug FROM checkout_links WHERE id = p_checkout_id;
    IF v_slug IS NOT NULL THEN RETURN v_slug; END IF;
    
    LOOP
        v_slug := 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12);
        SELECT EXISTS(SELECT 1 FROM checkout_links WHERE thank_you_slug = v_slug) INTO v_exists;
        EXIT WHEN NOT v_exists;
    END LOOP;
    
    UPDATE checkout_links SET thank_you_slug = v_slug WHERE id = p_checkout_id;
    RETURN v_slug;
END;
$$;

-- 3. Gerar thank_you_slug para TODOS os checkouts existentes
UPDATE checkout_links
SET thank_you_slug = 'ty-' || substr(md5(random()::text || id::text), 1, 12)
WHERE thank_you_slug IS NULL;

-- 4. Criar função get_checkout_by_slug CORRIGIDA (SEM pix_emv e SEM installments)
DROP FUNCTION IF EXISTS get_checkout_by_slug(TEXT);

CREATE OR REPLACE FUNCTION get_checkout_by_slug(p_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    -- Incrementar contador de acessos
    UPDATE checkout_links
    SET 
        access_count = access_count + 1,
        last_accessed_at = NOW()
    WHERE checkout_slug = p_slug;
    
    -- Buscar dados do checkout (SEM campos que não existem)
    SELECT jsonb_build_object(
        'id', cl.id,
        'checkout_slug', cl.checkout_slug,
        'thank_you_slug', cl.thank_you_slug,
        'payment_id', cl.payment_id,
        'user_id', cl.user_id,
        'customer_name', cl.customer_name,
        'customer_email', cl.customer_email,
        'customer_document', cl.customer_document,
        'customer_address', cl.customer_address,
        'product_name', p.product_name,
        'amount', cl.amount,
        'original_amount', cl.original_amount,
        'discount_percentage', cl.discount_percentage,
        'discount_amount', cl.discount_amount,
        'final_amount', cl.final_amount,
        'status', cl.status,
        'payment_status', p.status,
        'payment_bestfy_id', p.bestfy_id,
        'pix_qrcode', cl.pix_qrcode,
        'pix_expires_at', cl.pix_expires_at,
        'pix_generated_at', cl.pix_generated_at,
        'expires_at', cl.expires_at,
        'access_count', cl.access_count,
        'last_accessed_at', cl.last_accessed_at
    )
    INTO result
    FROM checkout_links cl
    LEFT JOIN payments p ON cl.payment_id = p.id
    WHERE cl.checkout_slug = p_slug;
    
    RETURN result;
END;
$$;

-- 5. Criar função access_thank_you_page
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
    -- Buscar o checkout pelo thank_you_slug
    SELECT id, payment_id INTO v_checkout_id, v_payment_id
    FROM checkout_links
    WHERE thank_you_slug = p_thank_you_slug;
    
    IF v_checkout_id IS NULL THEN
        RAISE EXCEPTION 'Página não encontrada ou expirada';
    END IF;
    
    -- Atualizar contadores de acesso
    UPDATE checkout_links
    SET 
        thank_you_accessed_at = NOW(),
        thank_you_access_count = COALESCE(thank_you_access_count, 0) + 1
    WHERE id = v_checkout_id;
    
    -- Marcar pagamento como recuperado se ainda não foi
    UPDATE payments
    SET 
        converted_from_recovery = TRUE,
        recovered_at = COALESCE(recovered_at, NOW())
    WHERE id = v_payment_id
    AND status = 'paid'
    AND (converted_from_recovery IS NULL OR converted_from_recovery = FALSE);
    
    RETURN jsonb_build_object(
        'success', true,
        'checkout_id', v_checkout_id,
        'payment_id', v_payment_id,
        'message', 'Acesso registrado e venda marcada como recuperada'
    );
END;
$$;

-- 6. Criar função get_thank_you_page
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

-- ===================================================================
-- ✅ VERIFICAÇÃO FINAL
-- ===================================================================
SELECT 
    '✅ VERIFICAÇÃO FINAL' as titulo,
    checkout_slug,
    status,
    thank_you_slug,
    pix_qrcode IS NOT NULL as tem_pix,
    CASE 
        WHEN thank_you_slug IS NOT NULL THEN '✅ PRONTO'
        ELSE '❌ PROBLEMA'
    END as resultado
FROM checkout_links
WHERE checkout_slug IN ('7huoo30x', '9mj9dmyq')
ORDER BY created_at DESC;

-- ===================================================================
-- 🎯 APÓS EXECUTAR:
-- ===================================================================
-- 1. Volte para: http://localhost:5173/checkout/9mj9dmyq
-- 2. A página deve carregar SEM erros
-- 3. Em 5 segundos, você será redirecionado automaticamente
-- 4. Se já estiver pago, o redirecionamento será imediato
-- ===================================================================

