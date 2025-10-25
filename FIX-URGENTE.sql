-- CORREÇÃO URGENTE: Gerar thank_you_slug para checkout específico
-- Execute este script AGORA no Supabase SQL Editor

-- 1. Verificar o checkout atual
SELECT 
  checkout_slug,
  thank_you_slug,
  payment_id
FROM checkout_links
WHERE checkout_slug = 'kmgwz95t';

-- 2. Se thank_you_slug for NULL, gerar agora
UPDATE checkout_links
SET thank_you_slug = 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12)
WHERE checkout_slug = 'kmgwz95t' AND thank_you_slug IS NULL;

-- 3. Verificar o status do pagamento
SELECT 
  p.id,
  p.bestfy_id,
  p.status,
  p.converted_from_recovery,
  cl.checkout_slug,
  cl.thank_you_slug
FROM checkout_links cl
JOIN payments p ON p.id = cl.payment_id
WHERE cl.checkout_slug = 'kmgwz95t';

-- 4. Mostrar URL de obrigado para acessar
SELECT 
  'http://localhost:5173/obrigado/' || thank_you_slug as URL_ACESSAR_AGORA
FROM checkout_links
WHERE checkout_slug = 'kmgwz95t';

-- 5. Se o pagamento já está pago, marcar como recuperado manualmente
DO $$
DECLARE
  v_payment_id uuid;
  v_status text;
BEGIN
  SELECT p.id, p.status INTO v_payment_id, v_status
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.checkout_slug = 'kmgwz95t';
  
  IF v_status = 'paid' THEN
    UPDATE payments
    SET 
      converted_from_recovery = true,
      recovered_at = NOW()
    WHERE id = v_payment_id
      AND COALESCE(converted_from_recovery, false) = false;
    
    RAISE NOTICE '✅ Pagamento marcado como recuperado!';
  ELSE
    RAISE NOTICE '⚠️ Pagamento ainda está com status: %', v_status;
  END IF;
END $$;

