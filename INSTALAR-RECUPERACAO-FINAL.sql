-- ============================================
-- INSTALAÇÃO COMPLETA DO SISTEMA DE RECUPERAÇÃO
-- Execute este script UMA VEZ no Supabase SQL Editor
-- ============================================

-- ============================================
-- PARTE 1: Adicionar Colunas Necessárias
-- ============================================

-- Tabela payments: colunas de recuperação
ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS converted_from_recovery boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS recovered_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_payments_converted_from_recovery 
ON payments(converted_from_recovery);

-- Tabela checkout_links: colunas do sistema de obrigado
ALTER TABLE checkout_links
ADD COLUMN IF NOT EXISTS thank_you_slug text,
ADD COLUMN IF NOT EXISTS thank_you_accessed_at timestamptz,
ADD COLUMN IF NOT EXISTS thank_you_access_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS original_amount numeric,
ADD COLUMN IF NOT EXISTS discount_percentage integer,
ADD COLUMN IF NOT EXISTS discount_amount numeric,
ADD COLUMN IF NOT EXISTS final_amount numeric,
ADD COLUMN IF NOT EXISTS pix_qrcode text,
ADD COLUMN IF NOT EXISTS pix_expires_at timestamptz,
ADD COLUMN IF NOT EXISTS pix_generated_at timestamptz,
ADD COLUMN IF NOT EXISTS customer_address jsonb,
ADD COLUMN IF NOT EXISTS access_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_accessed_at timestamptz;

-- Índice para busca rápida
CREATE INDEX IF NOT EXISTS idx_checkout_links_thank_you_slug 
ON checkout_links(thank_you_slug);

-- ============================================
-- PARTE 2: Funções Essenciais
-- ============================================

-- Função: Gerar slug único para página de obrigado
DROP FUNCTION IF EXISTS generate_thank_you_slug();
CREATE OR REPLACE FUNCTION generate_thank_you_slug()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  chars text := 'abcdefghijklmnopqrstuvwxyz0123456789';
  result text := '';
  i integer;
  slug_exists boolean := true;
BEGIN
  WHILE slug_exists LOOP
    result := 'ty-';
    FOR i IN 1..12 LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    SELECT EXISTS(
      SELECT 1 FROM checkout_links WHERE thank_you_slug = result
    ) INTO slug_exists;
  END LOOP;
  RETURN result;
END;
$$;

-- Função: Buscar checkout por slug (formato jsonb)
DROP FUNCTION IF EXISTS get_checkout_by_slug(text);
CREATE OR REPLACE FUNCTION get_checkout_by_slug(p_slug text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Incrementar contador
  UPDATE checkout_links
  SET 
    access_count = COALESCE(access_count, 0) + 1,
    last_accessed_at = NOW()
  WHERE checkout_slug = p_slug;
  
  -- Buscar dados
  SELECT jsonb_build_object(
    'checkout_slug', cl.checkout_slug,
    'thank_you_slug', cl.thank_you_slug,
    'id', cl.id,
    'customer_name', cl.customer_name,
    'customer_email', cl.customer_email,
    'customer_document', cl.customer_document,
    'product_name', cl.product_name,
    'amount', cl.amount,
    'original_amount', cl.original_amount,
    'discount_percentage', cl.discount_percentage,
    'discount_amount', cl.discount_amount,
    'final_amount', COALESCE(cl.final_amount, cl.amount),
    'expires_at', cl.expires_at,
    'items', cl.items,
    'metadata', cl.metadata,
    'pix_qrcode', cl.pix_qrcode,
    'pix_expires_at', cl.pix_expires_at,
    'pix_generated_at', cl.pix_generated_at,
    'customer_address', cl.customer_address,
    'payment_id', p.id,
    'payment_status', p.status,
    'payment_bestfy_id', p.bestfy_id
  )
  INTO v_result
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.checkout_slug = p_slug
  LIMIT 1;
  
  RETURN v_result;
END;
$$;

-- Função: Buscar página de obrigado por slug
DROP FUNCTION IF EXISTS get_thank_you_page(text);
CREATE OR REPLACE FUNCTION get_thank_you_page(p_thank_you_slug text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'thank_you_slug', cl.thank_you_slug,
    'customer_name', cl.customer_name,
    'customer_email', cl.customer_email,
    'product_name', cl.product_name,
    'amount', cl.amount,
    'final_amount', COALESCE(cl.final_amount, cl.amount),
    'payment_status', p.status,
    'payment_bestfy_id', p.bestfy_id,
    'checkout_slug', cl.checkout_slug
  )
  INTO v_result
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.thank_you_slug = p_thank_you_slug;
  
  RETURN v_result;
END;
$$;

-- Função: Acessar página de obrigado e marcar como recuperado
DROP FUNCTION IF EXISTS access_thank_you_page(text);
CREATE OR REPLACE FUNCTION access_thank_you_page(p_thank_you_slug text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_checkout RECORD;
BEGIN
  -- Buscar checkout
  SELECT 
    cl.id as checkout_id,
    cl.payment_id,
    p.status as payment_status
  INTO v_checkout
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.thank_you_slug = p_thank_you_slug;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Thank you page not found'
    );
  END IF;
  
  -- Incrementar contador de acesso à página de obrigado
  UPDATE checkout_links
  SET 
    thank_you_access_count = COALESCE(thank_you_access_count, 0) + 1,
    thank_you_accessed_at = COALESCE(thank_you_accessed_at, NOW())
  WHERE thank_you_slug = p_thank_you_slug;
  
  -- Se pagamento está pago, marcar como recuperado
  IF v_checkout.payment_status = 'paid' THEN
    UPDATE payments
    SET 
      converted_from_recovery = true,
      recovered_at = COALESCE(recovered_at, NOW())
    WHERE id = v_checkout.payment_id
      AND COALESCE(converted_from_recovery, false) = false;
    
    RETURN jsonb_build_object(
      'success', true,
      'payment_recovered', true
    );
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'payment_recovered', false,
    'payment_status', v_checkout.payment_status
  );
END;
$$;

-- ============================================
-- PARTE 3: Gerar thank_you_slug para Checkouts Existentes
-- ============================================

DO $$
DECLARE
  v_checkout RECORD;
  v_slug text;
  v_updated integer := 0;
BEGIN
  FOR v_checkout IN 
    SELECT id FROM checkout_links WHERE thank_you_slug IS NULL
  LOOP
    v_slug := generate_thank_you_slug();
    UPDATE checkout_links 
    SET thank_you_slug = v_slug 
    WHERE id = v_checkout.id;
    v_updated := v_updated + 1;
  END LOOP;
  
  RAISE NOTICE '✅ % checkouts atualizados com thank_you_slug', v_updated;
END $$;

-- ============================================
-- PARTE 4: Trigger para Novos Checkouts
-- ============================================

CREATE OR REPLACE FUNCTION auto_generate_thank_you_slug()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.thank_you_slug IS NULL THEN
    NEW.thank_you_slug := generate_thank_you_slug();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_generate_thank_you_slug ON checkout_links;
CREATE TRIGGER trigger_generate_thank_you_slug
  BEFORE INSERT ON checkout_links
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_thank_you_slug();

-- ============================================
-- VERIFICAÇÃO E RELATÓRIO FINAL
-- ============================================

DO $$
DECLARE
  v_checkouts_with_ty integer;
  v_checkouts_without_ty integer;
  v_recovered integer;
BEGIN
  SELECT COUNT(*) INTO v_checkouts_with_ty
  FROM checkout_links WHERE thank_you_slug IS NOT NULL;
  
  SELECT COUNT(*) INTO v_checkouts_without_ty
  FROM checkout_links WHERE thank_you_slug IS NULL;
  
  SELECT COUNT(*) INTO v_recovered
  FROM payments WHERE converted_from_recovery = true;
  
  RAISE NOTICE '';
  RAISE NOTICE '============================================';
  RAISE NOTICE '✅ INSTALAÇÃO COMPLETA DO SISTEMA DE RECUPERAÇÃO';
  RAISE NOTICE '============================================';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Estatísticas:';
  RAISE NOTICE '  - Checkouts com thank_you_slug: %', v_checkouts_with_ty;
  RAISE NOTICE '  - Checkouts sem thank_you_slug: %', v_checkouts_without_ty;
  RAISE NOTICE '  - Vendas recuperadas: %', v_recovered;
  RAISE NOTICE '';
  
  IF v_checkouts_without_ty > 0 THEN
    RAISE WARNING '⚠️ Ainda há % checkouts sem thank_you_slug!', v_checkouts_without_ty;
  ELSE
    RAISE NOTICE '✅ Todos os checkouts têm thank_you_slug!';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '🎉 Sistema instalado com sucesso!';
  RAISE NOTICE '';
END $$;

-- Mostrar exemplo de checkout atualizado
SELECT 
  checkout_slug,
  thank_you_slug,
  customer_name,
  'http://localhost:5173/obrigado/' || thank_you_slug as thank_you_url
FROM checkout_links
WHERE checkout_slug = 'hxgwa8q1';

