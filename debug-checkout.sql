-- Script de Debug para Verificar Estado do Checkout
-- Execute este script no Supabase SQL Editor

-- 1. Verificar se as colunas thank_you_slug existem
SELECT 
  column_name, 
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'checkout_links' 
  AND column_name IN ('thank_you_slug', 'thank_you_accessed_at', 'thank_you_access_count');

-- 2. Verificar se as colunas de recovery existem em payments
SELECT 
  column_name, 
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'payments' 
  AND column_name IN ('converted_from_recovery', 'recovered_at');

-- 3. Verificar se as funções existem
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public'
  AND routine_name IN (
    'generate_thank_you_slug',
    'access_thank_you_page',
    'get_thank_you_page',
    'mark_payment_as_recovered'
  );

-- 4. Verificar o checkout específico
SELECT 
  cl.checkout_slug,
  cl.thank_you_slug,
  cl.customer_name,
  p.status as payment_status,
  p.bestfy_id
FROM checkout_links cl
JOIN payments p ON p.id = cl.payment_id
WHERE cl.checkout_slug = 'xcplvs2l';

-- 5. Se thank_you_slug for NULL, gerar para todos os checkouts
-- DESCOMENTE E EXECUTE APENAS SE CONFIRMAR QUE A COLUNA EXISTE
-- UPDATE checkout_links
-- SET thank_you_slug = 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12)
-- WHERE thank_you_slug IS NULL;

-- 6. Verificar todos os checkouts sem thank_you_slug
SELECT 
  COUNT(*) as total_sem_thank_you_slug
FROM checkout_links
WHERE thank_you_slug IS NULL;

