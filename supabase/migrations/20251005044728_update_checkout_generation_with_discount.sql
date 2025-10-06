/*
  # Atualizar Geração de Checkout com Desconto de 20%

  1. Mudanças
    - Atualiza a função `generate_checkout_links_for_pending_payments` para calcular desconto
    - Aplica 20% de desconto automaticamente em todos os checkouts
    - Armazena valores original, desconto e final

  2. Cálculo
    - original_amount = valor do payment
    - discount_percentage = 20%
    - discount_amount = original_amount * 0.20
    - final_amount = original_amount - discount_amount
*/

-- Drop da função existente
DROP FUNCTION IF EXISTS generate_checkout_links_for_pending_payments();

-- Recria a função com cálculo de desconto
CREATE OR REPLACE FUNCTION generate_checkout_links_for_pending_payments()
RETURNS TABLE(
  checkout_slug TEXT,
  payment_id UUID,
  customer_email TEXT,
  original_amount DECIMAL,
  final_amount DECIMAL
) AS $$
DECLARE
  pending_payment RECORD;
  new_slug TEXT;
  original_amt DECIMAL;
  discount_pct DECIMAL := 20.00;
  discount_amt DECIMAL;
  final_amt DECIMAL;
BEGIN
  FOR pending_payment IN
    SELECT 
      p.id,
      p.customer_email,
      p.customer_name,
      p.customer_document,
      p.customer_address,
      p.amount,
      p.user_id
    FROM payments p
    LEFT JOIN checkout_links cl ON cl.payment_id = p.id
    WHERE p.status = 'waiting_payment'
      AND cl.id IS NULL
      AND p.customer_email IS NOT NULL
      AND p.customer_email != ''
      AND p.recovery_email_sent_at IS NULL
      AND p.created_at >= NOW() - INTERVAL '30 days'
    LIMIT 50
  LOOP
    -- Calcula valores com desconto
    original_amt := pending_payment.amount;
    discount_amt := ROUND(original_amt * (discount_pct / 100), 2);
    final_amt := original_amt - discount_amt;

    -- Gera slug único
    new_slug := LOWER(
      SUBSTRING(
        MD5(RANDOM()::TEXT || pending_payment.id::TEXT || NOW()::TEXT)
        FROM 1 FOR 8
      )
    );

    -- Insere o checkout link com valores de desconto
    INSERT INTO checkout_links (
      checkout_slug,
      payment_id,
      user_id,
      customer_email,
      customer_name,
      customer_document,
      customer_address,
      original_amount,
      discount_percentage,
      discount_amount,
      final_amount,
      status,
      access_count,
      created_at
    ) VALUES (
      new_slug,
      pending_payment.id,
      pending_payment.user_id,
      pending_payment.customer_email,
      pending_payment.customer_name,
      pending_payment.customer_document,
      pending_payment.customer_address,
      original_amt,
      discount_pct,
      discount_amt,
      final_amt,
      'pending',
      0,
      NOW()
    );

    -- Retorna informações do checkout criado
    RETURN QUERY SELECT 
      new_slug,
      pending_payment.id,
      pending_payment.customer_email,
      original_amt,
      final_amt;
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
