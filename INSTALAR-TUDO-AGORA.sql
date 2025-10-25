-- ============================================
-- INSTALAÇÃO COMPLETA - REDIRECIONAMENTO AUTOMÁTICO
-- Execute UMA VEZ no Supabase SQL Editor
-- ============================================

-- ============================================
-- PARTE 1: Criar Colunas Necessárias
-- ============================================

ALTER TABLE checkout_links 
ADD COLUMN IF NOT EXISTS thank_you_slug text,
ADD COLUMN IF NOT EXISTS thank_you_accessed_at timestamptz,
ADD COLUMN IF NOT EXISTS thank_you_access_count integer DEFAULT 0;

ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS converted_from_recovery boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS recovered_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_checkout_links_thank_you_slug ON checkout_links(thank_you_slug);
CREATE INDEX IF NOT EXISTS idx_payments_converted_from_recovery ON payments(converted_from_recovery);

-- ============================================
-- PARTE 2: Criar Função de Geração de Slug
-- ============================================

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
    SELECT EXISTS(SELECT 1 FROM checkout_links WHERE thank_you_slug = result) INTO slug_exists;
  END LOOP;
  RETURN result;
END;
$$;

-- ============================================
-- PARTE 3: Criar Função get_checkout_by_slug
-- Esta é A FUNÇÃO MAIS IMPORTANTE para o redirecionamento automático!
-- ============================================

DROP FUNCTION IF EXISTS get_checkout_by_slug(text);
CREATE OR REPLACE FUNCTION get_checkout_by_slug(p_slug text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Incrementar contador de acesso
  UPDATE checkout_links
  SET 
    access_count = COALESCE(access_count, 0) + 1,
    last_accessed_at = NOW()
  WHERE checkout_slug = p_slug;
  
  -- Buscar dados completos do checkout
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

-- ============================================
-- PARTE 4: Criar Função da Página de Obrigado
-- ============================================

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

-- ============================================
-- PARTE 5: Criar Função de Marcação como Recuperado
-- ============================================

DROP FUNCTION IF EXISTS access_thank_you_page(text);
CREATE OR REPLACE FUNCTION access_thank_you_page(p_thank_you_slug text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_checkout RECORD;
BEGIN
  -- Buscar checkout e payment
  SELECT 
    cl.id as checkout_id,
    cl.payment_id,
    p.status as payment_status
  INTO v_checkout
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.thank_you_slug = p_thank_you_slug;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not found');
  END IF;
  
  -- Incrementar contador
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
    
    RETURN jsonb_build_object('success', true, 'payment_recovered', true);
  END IF;
  
  RETURN jsonb_build_object('success', true, 'payment_recovered', false);
END;
$$;

-- ============================================
-- PARTE 6: Gerar thank_you_slug para TODOS os Checkouts
-- ============================================

UPDATE checkout_links
SET thank_you_slug = generate_thank_you_slug()
WHERE thank_you_slug IS NULL;

-- ============================================
-- PARTE 7: Criar Trigger para Novos Checkouts
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
-- VERIFICAÇÃO FINAL
-- ============================================

DO $$
DECLARE
  v_checkouts integer;
  v_recovered integer;
BEGIN
  SELECT COUNT(*) INTO v_checkouts FROM checkout_links WHERE thank_you_slug IS NOT NULL;
  SELECT COUNT(*) INTO v_recovered FROM payments WHERE converted_from_recovery = true;
  
  RAISE NOTICE '';
  RAISE NOTICE '============================================';
  RAISE NOTICE '✅ SISTEMA DE REDIRECIONAMENTO AUTOMÁTICO INSTALADO!';
  RAISE NOTICE '============================================';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Status:';
  RAISE NOTICE '  ✅ Checkouts com thank_you_slug: %', v_checkouts;
  RAISE NOTICE '  ✅ Vendas recuperadas: %', v_recovered;
  RAISE NOTICE '';
  RAISE NOTICE '🎯 O sistema agora irá:';
  RAISE NOTICE '  1. Detectar pagamento a cada 5 segundos';
  RAISE NOTICE '  2. Redirecionar AUTOMATICAMENTE para /obrigado/{slug}';
  RAISE NOTICE '  3. Marcar como RECUPERADO automaticamente';
  RAISE NOTICE '  4. Atualizar Dashboard com métricas';
  RAISE NOTICE '';
  RAISE NOTICE '🚀 Tudo pronto! Teste fazendo um pagamento agora.';
  RAISE NOTICE '';
END $$;

-- Mostrar alguns checkouts para teste
SELECT 
  checkout_slug,
  thank_you_slug,
  CASE 
    WHEN p.status = 'paid' THEN '✅ PAGO'
    ELSE '⏳ PENDENTE'
  END as status,
  CASE 
    WHEN p.converted_from_recovery THEN '💰 RECUPERADO'
    ELSE '⚪ NÃO RECUPERADO'
  END as recuperacao
FROM checkout_links cl
JOIN payments p ON p.id = cl.payment_id
ORDER BY cl.created_at DESC
LIMIT 5;

