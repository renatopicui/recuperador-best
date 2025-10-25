-- ============================================
-- EXECUTE ESTE SCRIPT AGORA NO SUPABASE
-- Copie e cole TUDO no SQL Editor e clique RUN
-- ============================================

-- 1. Adicionar coluna se não existir
ALTER TABLE checkout_links ADD COLUMN IF NOT EXISTS thank_you_slug text;

-- 2. Adicionar colunas de recuperação
ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS converted_from_recovery boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS recovered_at timestamptz;

-- 3. Gerar thank_you_slug para o checkout atual
UPDATE checkout_links
SET thank_you_slug = 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12)
WHERE checkout_slug = 'kmgwz95t' AND thank_you_slug IS NULL;

-- 4. Marcar pagamento como recuperado
UPDATE payments
SET 
  converted_from_recovery = true,
  recovered_at = NOW()
WHERE id IN (
  SELECT payment_id FROM checkout_links WHERE checkout_slug = 'kmgwz95t'
)
AND status = 'paid'
AND COALESCE(converted_from_recovery, false) = false;

-- 5. MOSTRAR URL PARA ACESSAR AGORA
SELECT 
  checkout_slug,
  thank_you_slug,
  '>>> ACESSE ESTA URL: http://localhost:5173/obrigado/' || thank_you_slug as URL_PARA_ACESSAR,
  CASE 
    WHEN p.converted_from_recovery THEN '✅ JÁ MARCADO COMO RECUPERADO'
    ELSE '⚠️ Ainda não marcado'
  END as status_recuperacao
FROM checkout_links cl
JOIN payments p ON p.id = cl.payment_id
WHERE checkout_slug = 'kmgwz95t';

