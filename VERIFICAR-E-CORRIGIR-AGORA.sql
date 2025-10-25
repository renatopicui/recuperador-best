-- ===================================================================
-- 🔥 VERIFICAR E CORRIGIR AGORA - EXECUTE NO SQL EDITOR DO SUPABASE
-- ===================================================================
-- Este script vai:
-- 1. Verificar o estado atual do banco
-- 2. Corrigir automaticamente os problemas
-- 3. Gerar thank_you_slug para todos os checkouts existentes
-- ===================================================================

-- PASSO 1: VERIFICAR CHECKOUTS PROBLEMÁTICOS
SELECT 
    checkout_slug,
    payment_status,
    thank_you_slug,
    created_at,
    CASE 
        WHEN payment_status = 'paid' AND thank_you_slug IS NULL THEN '❌ PROBLEMA: Pago sem thank_you_slug'
        WHEN payment_status = 'paid' AND thank_you_slug IS NOT NULL THEN '✅ OK: Pago com thank_you_slug'
        WHEN payment_status = 'pending' AND thank_you_slug IS NULL THEN '⏳ Aguardando pagamento'
        ELSE '❓ Estado desconhecido'
    END as status_diagnostico
FROM checkout_links
WHERE checkout_slug IN ('7huoo30x', '9mj9dmyq')
ORDER BY created_at DESC;

-- ===================================================================
-- PASSO 2: ADICIONAR COLUNAS (se não existirem)
-- ===================================================================

DO $$ 
BEGIN
    -- Adicionar thank_you_slug se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' 
        AND column_name = 'thank_you_slug'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_slug TEXT UNIQUE;
        RAISE NOTICE '✅ Coluna thank_you_slug adicionada';
    ELSE
        RAISE NOTICE '✓ Coluna thank_you_slug já existe';
    END IF;

    -- Adicionar thank_you_accessed_at se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' 
        AND column_name = 'thank_you_accessed_at'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_accessed_at TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE '✅ Coluna thank_you_accessed_at adicionada';
    ELSE
        RAISE NOTICE '✓ Coluna thank_you_accessed_at já existe';
    END IF;

    -- Adicionar thank_you_access_count se não existir
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' 
        AND column_name = 'thank_you_access_count'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_access_count INTEGER DEFAULT 0;
        RAISE NOTICE '✅ Coluna thank_you_access_count adicionada';
    ELSE
        RAISE NOTICE '✓ Coluna thank_you_access_count já existe';
    END IF;
END $$;

-- ===================================================================
-- PASSO 3: CRIAR FUNÇÃO generate_thank_you_slug
-- ===================================================================

CREATE OR REPLACE FUNCTION generate_thank_you_slug(p_checkout_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_slug TEXT;
    v_exists BOOLEAN;
BEGIN
    -- Verificar se já tem um slug
    SELECT thank_you_slug INTO v_slug
    FROM checkout_links
    WHERE id = p_checkout_id;
    
    IF v_slug IS NOT NULL THEN
        RETURN v_slug;
    END IF;
    
    -- Gerar novo slug único
    LOOP
        v_slug := 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12);
        
        SELECT EXISTS(
            SELECT 1 FROM checkout_links WHERE thank_you_slug = v_slug
        ) INTO v_exists;
        
        EXIT WHEN NOT v_exists;
    END LOOP;
    
    -- Atualizar o checkout com o novo slug
    UPDATE checkout_links
    SET thank_you_slug = v_slug
    WHERE id = p_checkout_id;
    
    RETURN v_slug;
END;
$$;

-- ===================================================================
-- PASSO 4: GERAR thank_you_slug PARA TODOS OS CHECKOUTS EXISTENTES
-- ===================================================================

DO $$
DECLARE
    checkout_record RECORD;
    new_slug TEXT;
BEGIN
    FOR checkout_record IN 
        SELECT id, checkout_slug 
        FROM checkout_links 
        WHERE thank_you_slug IS NULL
    LOOP
        new_slug := generate_thank_you_slug(checkout_record.id);
        RAISE NOTICE '✅ Gerado thank_you_slug para checkout %: %', 
            checkout_record.checkout_slug, new_slug;
    END LOOP;
END $$;

-- ===================================================================
-- PASSO 5: CRIAR/ATUALIZAR FUNÇÃO get_checkout_by_slug
-- ===================================================================

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
        'id', c.id,
        'checkout_slug', c.checkout_slug,
        'thank_you_slug', c.thank_you_slug,
        'payment_id', c.payment_id,
        'payment_status', c.payment_status,
        'pix_qrcode', c.pix_qrcode,
        'pix_emv', c.pix_emv,
        'pix_expiration', c.pix_expiration,
        'expires_at', c.expires_at,
        'access_count', c.access_count,
        'last_accessed_at', c.last_accessed_at,
        'customer_name', p.customer_name,
        'customer_email', p.customer_email,
        'product_name', p.product_name,
        'amount', p.amount,
        'final_amount', p.final_amount,
        'installments', p.installments,
        'payment_bestfy_id', p.payment_bestfy_id
    )
    INTO result
    FROM checkout_links c
    INNER JOIN payments p ON c.payment_id = p.id
    WHERE c.checkout_slug = p_slug;
    
    RETURN result;
END;
$$;

-- ===================================================================
-- PASSO 6: CRIAR FUNÇÃO access_thank_you_page
-- ===================================================================

DROP FUNCTION IF EXISTS access_thank_you_page(TEXT);

CREATE OR REPLACE FUNCTION access_thank_you_page(p_thank_you_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_checkout_id UUID;
    v_payment_id UUID;
    result JSONB;
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
    
    result := jsonb_build_object(
        'success', true,
        'checkout_id', v_checkout_id,
        'payment_id', v_payment_id,
        'message', 'Acesso registrado e venda marcada como recuperada'
    );
    
    RETURN result;
END;
$$;

-- ===================================================================
-- PASSO 7: CRIAR FUNÇÃO get_thank_you_page
-- ===================================================================

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
        'thank_you_slug', c.thank_you_slug,
        'checkout_slug', c.checkout_slug,
        'customer_name', p.customer_name,
        'customer_email', p.customer_email,
        'product_name', p.product_name,
        'amount', p.amount,
        'final_amount', p.final_amount,
        'payment_status', c.payment_status,
        'payment_bestfy_id', p.payment_bestfy_id
    )
    INTO result
    FROM checkout_links c
    INNER JOIN payments p ON c.payment_id = p.id
    WHERE c.thank_you_slug = p_thank_you_slug;
    
    IF result IS NULL THEN
        RAISE EXCEPTION 'Página não encontrada';
    END IF;
    
    RETURN result;
END;
$$;

-- ===================================================================
-- PASSO 8: VERIFICAÇÃO FINAL
-- ===================================================================

SELECT 
    '✅ VERIFICAÇÃO FINAL' as titulo,
    checkout_slug,
    payment_status,
    thank_you_slug,
    CASE 
        WHEN payment_status = 'paid' AND thank_you_slug IS NOT NULL THEN '✅ RESOLVIDO'
        WHEN payment_status = 'paid' AND thank_you_slug IS NULL THEN '❌ AINDA COM PROBLEMA'
        ELSE '⏳ Pendente'
    END as status_final
FROM checkout_links
WHERE checkout_slug IN ('7huoo30x', '9mj9dmyq')
ORDER BY created_at DESC;

-- ===================================================================
-- 🎯 PRÓXIMOS PASSOS APÓS EXECUTAR ESTE SCRIPT:
-- ===================================================================
-- 1. Volte para: http://localhost:5173/checkout/9mj9dmyq
-- 2. Em até 5 segundos, você será AUTOMATICAMENTE redirecionado
-- 3. A página de obrigado será aberta
-- 4. A venda será marcada como recuperada
-- 
-- Se não redirecionar automaticamente:
-- 1. Pressione F5 para recarregar a página
-- 2. Aguarde 5 segundos
-- 3. O redirecionamento acontecerá
-- ===================================================================

