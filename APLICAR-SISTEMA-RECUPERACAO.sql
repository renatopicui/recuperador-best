-- ============================================
-- SISTEMA DE RECUPERAÇÃO v2.0 - INSTALAÇÃO COMPLETA
-- Execute este script no Supabase SQL Editor
-- ============================================

-- ============================================
-- PARTE 1: Sistema Básico de Recuperação
-- ============================================

-- Adicionar campos para rastrear transações recuperadas
ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS converted_from_recovery boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS recovered_at timestamptz;

-- Criar índice para performance
CREATE INDEX IF NOT EXISTS idx_payments_converted_from_recovery ON payments(converted_from_recovery);

-- Função para marcar transação como recuperada
DROP FUNCTION IF EXISTS mark_payment_as_recovered(uuid);

CREATE OR REPLACE FUNCTION mark_payment_as_recovered(p_payment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_checkout_exists boolean;
  v_payment_status text;
BEGIN
  -- Verificar se existe um checkout link para este pagamento
  SELECT EXISTS(
    SELECT 1 FROM checkout_links WHERE payment_id = p_payment_id
  ) INTO v_checkout_exists;
  
  -- Verificar o status atual do pagamento
  SELECT status INTO v_payment_status
  FROM payments
  WHERE id = p_payment_id;
  
  -- Se existe checkout e o pagamento foi pago, marcar como recuperado
  IF v_checkout_exists AND v_payment_status = 'paid' THEN
    UPDATE payments
    SET 
      converted_from_recovery = true,
      recovered_at = NOW()
    WHERE id = p_payment_id
      AND converted_from_recovery = false;
    
    RETURN jsonb_build_object(
      'success', true,
      'payment_id', p_payment_id,
      'marked_as_recovered', true,
      'timestamp', NOW()
    );
  END IF;
  
  RETURN jsonb_build_object(
    'success', false,
    'payment_id', p_payment_id,
    'marked_as_recovered', false,
    'reason', 'Payment not paid or no checkout link found'
  );
END;
$$;

-- ============================================
-- PARTE 2: Sistema de Página de Obrigado
-- ============================================

-- Adicionar campos para rastreamento de página de obrigado
ALTER TABLE checkout_links 
ADD COLUMN IF NOT EXISTS thank_you_slug text UNIQUE,
ADD COLUMN IF NOT EXISTS thank_you_accessed_at timestamptz,
ADD COLUMN IF NOT EXISTS thank_you_access_count integer DEFAULT 0;

-- Adicionar campos que podem estar faltando na estrutura do checkout_links
ALTER TABLE checkout_links
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

-- Criar índice para busca rápida por thank_you_slug
CREATE INDEX IF NOT EXISTS idx_checkout_links_thank_you_slug ON checkout_links(thank_you_slug);

-- Função para gerar thank_you_slug único
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
    result := 'ty-'; -- prefixo "ty" para "thank you"
    FOR i IN 1..12 LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    
    SELECT EXISTS(SELECT 1 FROM checkout_links WHERE thank_you_slug = result) INTO slug_exists;
  END LOOP;
  
  RETURN result;
END;
$$;

-- Trigger para gerar thank_you_slug automaticamente ao criar checkout
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

-- Gerar thank_you_slug para checkouts existentes
UPDATE checkout_links
SET thank_you_slug = generate_thank_you_slug()
WHERE thank_you_slug IS NULL;

-- Função para acessar página de obrigado e marcar como recuperado
DROP FUNCTION IF EXISTS access_thank_you_page(text);

CREATE OR REPLACE FUNCTION access_thank_you_page(p_thank_you_slug text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_checkout_link RECORD;
  v_payment_id uuid;
BEGIN
  -- Buscar o checkout link
  SELECT 
    cl.id,
    cl.payment_id,
    cl.customer_name,
    cl.customer_email,
    cl.product_name,
    cl.amount,
    cl.final_amount,
    p.status as payment_status,
    p.bestfy_id
  INTO v_checkout_link
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.thank_you_slug = p_thank_you_slug;
  
  -- Se não encontrou, retornar erro
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Thank you page not found'
    );
  END IF;
  
  -- Incrementar contador de acesso à página de obrigado
  UPDATE checkout_links
  SET 
    thank_you_access_count = thank_you_access_count + 1,
    thank_you_accessed_at = NOW()
  WHERE thank_you_slug = p_thank_you_slug;
  
  -- Se o pagamento está pago e ainda não foi marcado como recuperado, marcar agora
  IF v_checkout_link.payment_status = 'paid' THEN
    UPDATE payments
    SET 
      converted_from_recovery = true,
      recovered_at = COALESCE(recovered_at, NOW())
    WHERE id = v_checkout_link.payment_id
      AND (converted_from_recovery IS NULL OR converted_from_recovery = false);
    
    RETURN jsonb_build_object(
      'success', true,
      'payment_recovered', true,
      'checkout_data', jsonb_build_object(
        'customer_name', v_checkout_link.customer_name,
        'customer_email', v_checkout_link.customer_email,
        'product_name', v_checkout_link.product_name,
        'amount', v_checkout_link.final_amount,
        'bestfy_id', v_checkout_link.bestfy_id
      )
    );
  END IF;
  
  -- Se o pagamento ainda não está pago
  RETURN jsonb_build_object(
    'success', true,
    'payment_recovered', false,
    'payment_status', v_checkout_link.payment_status,
    'checkout_data', jsonb_build_object(
      'customer_name', v_checkout_link.customer_name,
      'product_name', v_checkout_link.product_name
    )
  );
END;
$$;

-- Função para obter dados da página de obrigado
DROP FUNCTION IF EXISTS get_thank_you_page(text);

CREATE OR REPLACE FUNCTION get_thank_you_page(p_thank_you_slug text)
RETURNS TABLE (
  thank_you_slug text,
  customer_name text,
  customer_email text,
  product_name text,
  amount numeric,
  final_amount numeric,
  payment_status text,
  payment_bestfy_id text,
  checkout_slug text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cl.thank_you_slug,
    cl.customer_name,
    cl.customer_email,
    cl.product_name,
    cl.amount,
    COALESCE(cl.final_amount, cl.amount) as final_amount,
    p.status as payment_status,
    p.bestfy_id as payment_bestfy_id,
    cl.checkout_slug
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.thank_you_slug = p_thank_you_slug;
END;
$$;

-- ============================================
-- PARTE 3: Atualizar get_checkout_by_slug
-- ============================================

-- Criar função para incrementar contador de acesso (se não existir)
CREATE OR REPLACE FUNCTION increment_checkout_access(slug text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE checkout_links
  SET 
    access_count = COALESCE(access_count, 0) + 1,
    last_accessed_at = NOW()
  WHERE checkout_slug = slug;
END;
$$;

-- Dropar função existente para recriar com nova estrutura
DROP FUNCTION IF EXISTS get_checkout_by_slug(text);

CREATE OR REPLACE FUNCTION get_checkout_by_slug(slug text)
RETURNS TABLE (
  checkout_slug text,
  thank_you_slug text,
  customer_name text,
  customer_email text,
  customer_document text,
  product_name text,
  amount numeric,
  original_amount numeric,
  discount_percentage integer,
  discount_amount numeric,
  final_amount numeric,
  items jsonb,
  metadata jsonb,
  expires_at timestamptz,
  payment_status text,
  payment_bestfy_id text,
  payment_id uuid,
  pix_qrcode text,
  pix_expires_at timestamptz,
  pix_generated_at timestamptz,
  customer_address jsonb,
  id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM increment_checkout_access(slug);
  
  RETURN QUERY
  SELECT 
    cl.checkout_slug::text,
    cl.thank_you_slug::text,
    cl.customer_name::text,
    cl.customer_email::text,
    COALESCE(cl.customer_document, '')::text,
    cl.product_name::text,
    cl.amount::numeric,
    COALESCE(cl.original_amount, cl.amount)::numeric,
    COALESCE(cl.discount_percentage, 0)::integer,
    COALESCE(cl.discount_amount, 0)::numeric,
    COALESCE(cl.final_amount, cl.amount)::numeric,
    COALESCE(cl.items, '{}'::jsonb)::jsonb,
    COALESCE(cl.metadata, '{}'::jsonb)::jsonb,
    cl.expires_at::timestamptz,
    COALESCE(p.status, 'waiting_payment')::text,
    COALESCE(p.bestfy_id, '')::text,
    p.id::uuid,
    COALESCE(cl.pix_qrcode, '')::text,
    cl.pix_expires_at::timestamptz,
    cl.pix_generated_at::timestamptz,
    COALESCE(cl.customer_address, '{}'::jsonb)::jsonb,
    cl.id::uuid
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.checkout_slug = slug
    AND cl.expires_at > NOW();
END;
$$;

-- ============================================
-- VERIFICAÇÃO FINAL
-- ============================================

-- Verificar se tudo foi criado corretamente
DO $$
DECLARE
  v_columns_count integer;
  v_functions_count integer;
BEGIN
  -- Verificar colunas
  SELECT COUNT(*) INTO v_columns_count
  FROM information_schema.columns 
  WHERE table_name = 'checkout_links' 
    AND column_name IN ('thank_you_slug', 'thank_you_accessed_at', 'thank_you_access_count');
  
  -- Verificar funções
  SELECT COUNT(*) INTO v_functions_count
  FROM information_schema.routines 
  WHERE routine_schema = 'public'
    AND routine_name IN (
      'generate_thank_you_slug',
      'access_thank_you_page',
      'get_thank_you_page',
      'mark_payment_as_recovered'
    );
  
  RAISE NOTICE '✅ Instalação concluída!';
  RAISE NOTICE '   - Colunas criadas: % de 3', v_columns_count;
  RAISE NOTICE '   - Funções criadas: % de 4', v_functions_count;
  
  IF v_columns_count = 3 AND v_functions_count = 4 THEN
    RAISE NOTICE '✅ Sistema de Recuperação v2.0 instalado com sucesso!';
  ELSE
    RAISE WARNING '⚠️ Algo não foi criado corretamente. Verifique os erros acima.';
  END IF;
END $$;

-- Mostrar estatísticas
SELECT 
  'Checkouts com thank_you_slug' as tipo,
  COUNT(*) as quantidade
FROM checkout_links
WHERE thank_you_slug IS NOT NULL

UNION ALL

SELECT 
  'Checkouts sem thank_you_slug' as tipo,
  COUNT(*) as quantidade
FROM checkout_links
WHERE thank_you_slug IS NULL

UNION ALL

SELECT 
  'Pagamentos recuperados' as tipo,
  COUNT(*) as quantidade
FROM payments
WHERE converted_from_recovery = true;

