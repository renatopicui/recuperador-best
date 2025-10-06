/*
  # Adicionar colunas payment_method e secure_url

  1. Novas Colunas
    - `payment_method` (text, nullable) - Método de pagamento (pix, credit_card, etc)
    - `secure_url` (text, nullable) - URL segura para checkout da Bestfy

  2. Índices
    - Adiciona índice para payment_method para consultas rápidas

  3. Compatibilidade
    - Colunas opcionais para manter compatibilidade com dados existentes
*/

-- Adicionar coluna payment_method
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'payments' AND column_name = 'payment_method'
  ) THEN
    ALTER TABLE payments ADD COLUMN payment_method text;
  END IF;
END $$;

-- Adicionar coluna secure_url
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'payments' AND column_name = 'secure_url'
  ) THEN
    ALTER TABLE payments ADD COLUMN secure_url text;
  END IF;
END $$;

-- Adicionar índice para payment_method (útil para filtrar PIX)
CREATE INDEX IF NOT EXISTS idx_payments_payment_method 
ON payments (payment_method);

-- Adicionar comentários nas colunas
COMMENT ON COLUMN payments.payment_method IS 'Método de pagamento (pix, credit_card, boleto, etc)';
COMMENT ON COLUMN payments.secure_url IS 'URL segura para checkout da Bestfy';