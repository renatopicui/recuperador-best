-- ============================================
-- FIX DEFINITIVO - Sistema de Redirecionamento
-- Execute este script AGORA no Supabase SQL Editor
-- ============================================

-- 1. Adicionar colunas se não existirem
ALTER TABLE checkout_links ADD COLUMN IF NOT EXISTS thank_you_slug text;
ALTER TABLE checkout_links ADD COLUMN IF NOT EXISTS access_count integer DEFAULT 0;
ALTER TABLE checkout_links ADD COLUMN IF NOT EXISTS last_accessed_at timestamptz;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS converted_from_recovery boolean DEFAULT false;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS recovered_at timestamptz;

-- 2. CRIAR FUNÇÃO get_checkout_by_slug (ESSENCIAL PARA O POLLING!)
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
  
  -- Buscar dados ATUALIZADOS do banco
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
    'payment_status', p.status,  -- ← CAMPO CRUCIAL!
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

-- 3. Gerar thank_you_slug para TODOS os checkouts sem
UPDATE checkout_links
SET thank_you_slug = 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12)
WHERE thank_you_slug IS NULL;

-- 4. Criar funções auxiliares
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

DROP FUNCTION IF EXISTS access_thank_you_page(text);
CREATE OR REPLACE FUNCTION access_thank_you_page(p_thank_you_slug text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_payment_id uuid;
  v_status text;
BEGIN
  SELECT p.id, p.status INTO v_payment_id, v_status
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.thank_you_slug = p_thank_you_slug;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not found');
  END IF;
  
  IF v_status = 'paid' THEN
    UPDATE payments
    SET converted_from_recovery = true, recovered_at = NOW()
    WHERE id = v_payment_id AND COALESCE(converted_from_recovery, false) = false;
    
    RETURN jsonb_build_object('success', true, 'payment_recovered', true);
  END IF;
  
  RETURN jsonb_build_object('success', true, 'payment_recovered', false);
END;
$$;

-- ============================================
-- TESTE IMEDIATO
-- ============================================

-- Verificar checkout 7huoo30x
SELECT '=== TESTE: Checkout 7huoo30x ===' as teste;

SELECT 
  cl.checkout_slug,
  cl.thank_you_slug,
  p.status as payment_status,
  'http://localhost:5173/obrigado/' || cl.thank_you_slug as url_obrigado
FROM checkout_links cl
JOIN payments p ON p.id = cl.payment_id
WHERE cl.checkout_slug = '7huoo30x';

-- Testar função get_checkout_by_slug
SELECT '=== TESTE: Função get_checkout_by_slug ===' as teste;
SELECT get_checkout_by_slug('7huoo30x');

-- Verificação geral
SELECT '=== RESUMO GERAL ===' as teste;
SELECT 
  COUNT(*) as total_checkouts,
  COUNT(*) FILTER (WHERE thank_you_slug IS NOT NULL) as com_thank_you_slug,
  COUNT(*) FILTER (WHERE thank_you_slug IS NULL) as sem_thank_you_slug
FROM checkout_links;

-- Status
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '============================================';
  RAISE NOTICE '✅ SISTEMA DE REDIRECIONAMENTO INSTALADO!';
  RAISE NOTICE '============================================';
  RAISE NOTICE '';
  RAISE NOTICE '🎯 O que acontece agora:';
  RAISE NOTICE '  1. Página verifica status A CADA 5 SEGUNDOS';
  RAISE NOTICE '  2. Função get_checkout_by_slug retorna status atualizado';
  RAISE NOTICE '  3. Quando status = paid, redireciona automaticamente';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Para testar:';
  RAISE NOTICE '  1. Abra: http://localhost:5173/checkout/7huoo30x';
  RAISE NOTICE '  2. Aguarde até 5 segundos';
  RAISE NOTICE '  3. Deve redirecionar para /obrigado/ty-...';
  RAISE NOTICE '';
END $$;

