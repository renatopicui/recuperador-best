/*
  # Sistema de Rastreamento de Transações Recuperadas
  
  1. Adiciona campo para rastrear transações recuperadas
  2. Cria função para marcar transação como recuperada
  3. Adiciona trigger para marcar automaticamente
*/

-- Adicionar campo para rastrear se a transação foi recuperada
ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS converted_from_recovery boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS recovered_at timestamptz;

-- Criar índice para performance
CREATE INDEX IF NOT EXISTS idx_payments_converted_from_recovery ON payments(converted_from_recovery);

-- Função para marcar transação como recuperada
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

-- Trigger para marcar automaticamente quando o status mudar para 'paid'
CREATE OR REPLACE FUNCTION auto_mark_recovered_on_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_has_checkout boolean;
BEGIN
  -- Se o pagamento mudou para 'paid'
  IF NEW.status = 'paid' AND (OLD.status IS NULL OR OLD.status != 'paid') THEN
    -- Verificar se existe checkout link associado
    SELECT EXISTS(
      SELECT 1 FROM checkout_links WHERE payment_id = NEW.id
    ) INTO v_has_checkout;
    
    -- Se existe checkout, marcar como recuperado
    IF v_has_checkout AND (NEW.converted_from_recovery IS NULL OR NEW.converted_from_recovery = false) THEN
      NEW.converted_from_recovery := true;
      NEW.recovered_at := NOW();
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Criar trigger
DROP TRIGGER IF EXISTS trigger_auto_mark_recovered ON payments;
CREATE TRIGGER trigger_auto_mark_recovered
  BEFORE UPDATE ON payments
  FOR EACH ROW
  EXECUTE FUNCTION auto_mark_recovered_on_payment();

-- Comentários para documentação
COMMENT ON COLUMN payments.converted_from_recovery IS 'Indica se este pagamento foi recuperado através de um checkout link';
COMMENT ON COLUMN payments.recovered_at IS 'Data e hora em que o pagamento foi marcado como recuperado';
COMMENT ON FUNCTION mark_payment_as_recovered IS 'Marca manualmente um pagamento como recuperado';
COMMENT ON FUNCTION auto_mark_recovered_on_payment IS 'Trigger que marca automaticamente pagamentos como recuperados quando são pagos e tem checkout link';

