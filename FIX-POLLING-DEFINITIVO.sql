-- ============================================
-- CORRIGIR POLLING - FAZER FUNCIONAR AGORA
-- Execute este script no Supabase SQL Editor
-- ============================================

-- PARTE 1: Adicionar colunas necessárias
ALTER TABLE checkout_links 
ADD COLUMN IF NOT EXISTS thank_you_slug text,
ADD COLUMN IF NOT EXISTS access_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_accessed_at timestamptz;

ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS converted_from_recovery boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS recovered_at timestamptz;

-- PARTE 2: Dropar e recriar a função get_checkout_by_slug
-- Esta é A FUNÇÃO QUE O POLLING USA!
DROP FUNCTION IF EXISTS get_checkout_by_slug(text);

CREATE OR REPLACE FUNCTION get_checkout_by_slug(p_slug text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Atualizar contador de acesso
  UPDATE checkout_links
  SET 
    access_count = COALESCE(access_count, 0) + 1,
    last_accessed_at = NOW()
  WHERE checkout_slug = p_slug;
  
  -- Buscar dados ATUALIZADOS do checkout e payment
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
    'payment_status', p.status,  -- ← ESTE É O CAMPO IMPORTANTE!
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

-- PARTE 3: Gerar thank_you_slug para TODOS os checkouts
UPDATE checkout_links
SET thank_you_slug = 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12)
WHERE thank_you_slug IS NULL;

-- PARTE 4: Criar trigger para novos checkouts
CREATE OR REPLACE FUNCTION auto_generate_thank_you_slug()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.thank_you_slug IS NULL THEN
    NEW.thank_you_slug := 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_generate_thank_you_slug ON checkout_links;
CREATE TRIGGER trigger_generate_thank_you_slug
  BEFORE INSERT ON checkout_links
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_thank_you_slug();

-- PARTE 5: TESTAR A FUNÇÃO COM O CHECKOUT 7huoo30x
SELECT 
  'TESTE DA FUNÇÃO get_checkout_by_slug:' as info,
  get_checkout_by_slug('7huoo30x') as resultado;

-- PARTE 6: Verificar se o status está sendo retornado corretamente
SELECT 
  cl.checkout_slug,
  p.status as status_atual_no_banco,
  (get_checkout_by_slug('7huoo30x')->>'payment_status') as status_retornado_pela_funcao,
  cl.thank_you_slug,
  CASE 
    WHEN p.status = (get_checkout_by_slug('7huoo30x')->>'payment_status') 
    THEN '✅ FUNÇÃO ESTÁ RETORNANDO O STATUS CORRETO'
    ELSE '❌ FUNÇÃO NÃO ESTÁ RETORNANDO O STATUS ATUALIZADO'
  END as verificacao
FROM checkout_links cl
JOIN payments p ON p.id = cl.payment_id
WHERE cl.checkout_slug = '7huoo30x';

-- PARTE 7: Mostrar URL de obrigado
SELECT 
  checkout_slug,
  'Status no banco: ' || p.status as status,
  'URL de obrigado: http://localhost:5173/obrigado/' || thank_you_slug as url_obrigado
FROM checkout_links cl
JOIN payments p ON p.id = cl.payment_id
WHERE checkout_slug = '7huoo30x';

-- MENSAGEM FINAL
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '============================================';
  RAISE NOTICE '✅ FUNÇÃO get_checkout_by_slug() RECRIADA!';
  RAISE NOTICE '============================================';
  RAISE NOTICE '';
  RAISE NOTICE '🔄 O que acontece agora:';
  RAISE NOTICE '  1. Página faz polling a cada 5 segundos';
  RAISE NOTICE '  2. Chama get_checkout_by_slug(''7huoo30x'')';
  RAISE NOTICE '  3. Função retorna status ATUALIZADO do banco';
  RAISE NOTICE '  4. Se status = ''paid'', redireciona automaticamente';
  RAISE NOTICE '';
  RAISE NOTICE '🧪 Para testar AGORA:';
  RAISE NOTICE '  1. Mantenha a página /checkout/7huoo30x aberta';
  RAISE NOTICE '  2. Aguarde até 5 segundos';
  RAISE NOTICE '  3. Deve redirecionar automaticamente!';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Ou acesse manualmente a URL mostrada acima';
  RAISE NOTICE '';
END $$;

