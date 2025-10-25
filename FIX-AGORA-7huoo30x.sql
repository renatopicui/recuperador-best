-- CORREÇÃO URGENTE PARA CHECKOUT 7huoo30x
-- Execute AGORA no Supabase SQL Editor

-- 1. Gerar thank_you_slug se não existir
UPDATE checkout_links
SET thank_you_slug = 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12)
WHERE checkout_slug = '7huoo30x' AND thank_you_slug IS NULL;

-- 2. Marcar como recuperado
UPDATE payments
SET 
  converted_from_recovery = true,
  recovered_at = NOW()
WHERE id IN (SELECT payment_id FROM checkout_links WHERE checkout_slug = '7huoo30x')
  AND status = 'paid'
  AND COALESCE(converted_from_recovery, false) = false;

-- 3. MOSTRAR URL PARA ACESSAR
SELECT 
  '🚀 COPIE E ACESSE AGORA: http://localhost:5173/obrigado/' || thank_you_slug as URL_OBRIGADO
FROM checkout_links
WHERE checkout_slug = '7huoo30x';

