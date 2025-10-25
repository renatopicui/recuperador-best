-- ===================================================================
-- 🔥 RESOLVER DEFINITIVO AGORA - EXECUTE NO SUPABASE SQL EDITOR
-- ===================================================================
-- Este script vai resolver TUDO de uma vez por todas
-- ===================================================================

-- PASSO 1: Adicionar colunas necessárias
DO $$ 
BEGIN
    -- Coluna thank_you_slug
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' AND column_name = 'thank_you_slug'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_slug TEXT;
        RAISE NOTICE '✅ Coluna thank_you_slug adicionada';
    ELSE
        RAISE NOTICE '✓ Coluna thank_you_slug já existe';
    END IF;
    
    -- Coluna thank_you_accessed_at
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'checkout_links' AND column_name = 'thank_you_accessed_at'
    ) THEN
        ALTER TABLE checkout_links ADD COLUMN thank_you_accessed_at TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE '✅ Coluna thank_you_accessed_at adicionada';
    ELSE
        RAISE NOTICE '✓ Coluna thank_you_accessed_at já existe';
    END IF;
    
    -- Coluna thank_you_access_count
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

-- PASSO 2: Criar índice único para thank_you_slug
CREATE UNIQUE INDEX IF NOT EXISTS idx_checkout_links_thank_you_slug 
ON checkout_links(thank_you_slug);

-- PASSO 3: Gerar thank_you_slug para TODOS os checkouts (inclusive os já existentes)
UPDATE checkout_links
SET thank_you_slug = 'ty-' || substr(md5(random()::text || id::text || checkout_slug::text || NOW()::text), 1, 12)
WHERE thank_you_slug IS NULL;

-- PASSO 4: Criar função get_checkout_by_slug (VERSÃO DEFINITIVA)
DROP FUNCTION IF EXISTS get_checkout_by_slug(TEXT);

CREATE OR REPLACE FUNCTION get_checkout_by_slug(p_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
BEGIN
    -- Buscar dados do checkout + payment
    SELECT jsonb_build_object(
        -- Dados do checkout_links
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
        'pix_qrcode', cl.pix_qrcode,
        'pix_expires_at', cl.pix_expires_at,
        'expires_at', cl.expires_at,
        -- Dados do payment
        'payment_status', p.status,
        'payment_bestfy_id', p.bestfy_id,
        'product_name', p.product_name
    )
    INTO result
    FROM checkout_links cl
    LEFT JOIN payments p ON cl.payment_id = p.id
    WHERE cl.checkout_slug = p_slug;
    
    RETURN result;
END;
$$;

-- PASSO 5: Criar função para acessar página de obrigado
DROP FUNCTION IF EXISTS access_thank_you_page(TEXT);

CREATE OR REPLACE FUNCTION access_thank_you_page(p_thank_you_slug TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_checkout_id UUID;
    v_payment_id UUID;
    v_result JSONB;
BEGIN
    -- Buscar checkout pelo thank_you_slug
    SELECT id, payment_id INTO v_checkout_id, v_payment_id
    FROM checkout_links
    WHERE thank_you_slug = p_thank_you_slug;
    
    IF v_checkout_id IS NULL THEN
        RAISE EXCEPTION 'Página não encontrada ou expirada';
    END IF;
    
    -- Atualizar contadores de acesso na página de obrigado
    UPDATE checkout_links
    SET 
        thank_you_accessed_at = NOW(),
        thank_you_access_count = COALESCE(thank_you_access_count, 0) + 1
    WHERE id = v_checkout_id;
    
    -- Marcar pagamento como recuperado (SE estiver pago)
    UPDATE payments
    SET 
        converted_from_recovery = TRUE,
        recovered_at = COALESCE(recovered_at, NOW())
    WHERE id = v_payment_id
    AND status = 'paid'
    AND (converted_from_recovery IS NULL OR converted_from_recovery = FALSE);
    
    v_result := jsonb_build_object(
        'success', true,
        'checkout_id', v_checkout_id,
        'payment_id', v_payment_id,
        'message', 'Acesso registrado com sucesso'
    );
    
    RETURN v_result;
END;
$$;

-- PASSO 6: Criar função para buscar dados da página de obrigado
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
-- ✅ VERIFICAÇÃO: Checar se os checkouts problemáticos estão OK
-- ===================================================================
SELECT 
    '✅ CHECKOUTS VERIFICADOS' as titulo,
    checkout_slug,
    status as checkout_status,
    thank_you_slug,
    (SELECT status FROM payments WHERE id = checkout_links.payment_id) as payment_status,
    CASE 
        WHEN thank_you_slug IS NOT NULL THEN '✅ PRONTO - VAI FUNCIONAR'
        ELSE '❌ PROBLEMA - FALTA SLUG'
    END as resultado
FROM checkout_links
WHERE checkout_slug IN ('7huoo30x', '9mj9dmyq', 'y2ji98vb')
ORDER BY created_at DESC;

-- ===================================================================
-- 📊 ESTATÍSTICAS FINAIS
-- ===================================================================
SELECT 
    '📊 ESTATÍSTICAS' as titulo,
    COUNT(*) as total_checkouts,
    COUNT(thank_you_slug) as com_thank_you_slug,
    COUNT(*) - COUNT(thank_you_slug) as sem_thank_you_slug,
    CASE 
        WHEN COUNT(*) = COUNT(thank_you_slug) THEN '✅ TODOS TÊM SLUG'
        ELSE '⚠️ ALGUNS SEM SLUG'
    END as status_geral
FROM checkout_links;

-- ===================================================================
-- 🎯 PRONTO! AGORA FUNCIONA ASSIM:
-- ===================================================================
-- 1. Webhook atualiza payments.status = 'paid'
-- 2. Frontend faz polling a cada 5 segundos
-- 3. get_checkout_by_slug retorna payment_status = 'paid' + thank_you_slug
-- 4. Frontend detecta paid + thank_you_slug
-- 5. Redireciona para /obrigado/{thank_you_slug}
-- 6. Página de obrigado marca como recuperado automaticamente
-- ===================================================================

