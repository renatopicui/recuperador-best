/*
  # Adicionar coluna de status na tabela payments

  1. Alterações na tabela
    - Adiciona coluna `status` na tabela `payments`
    - Define valor padrão como 'waiting_payment'
    - Permite valores: waiting_payment, paid, refused

  2. Índices
    - Adiciona índice na coluna status para consultas rápidas
*/

-- Adiciona a coluna status se ela não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'payments' AND column_name = 'status'
  ) THEN
    ALTER TABLE payments ADD COLUMN status text DEFAULT 'waiting_payment';
  END IF;
END $$;

-- Cria índice na coluna status para melhor performance
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);

-- Adiciona comentário na coluna
COMMENT ON COLUMN payments.status IS 'Status do pagamento: waiting_payment, paid, refused';