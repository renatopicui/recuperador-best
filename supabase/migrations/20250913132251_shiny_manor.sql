/*
  # Criar tabela de pagamentos

  1. Nova Tabela
    - `payments`
      - `id` (uuid, chave primária)
      - `bestfy_id` (text, ID único da Bestfy)
      - `customer_name` (text, nome do cliente)
      - `customer_email` (text, email do cliente)
      - `customer_phone` (text, telefone do cliente)
      - `product_name` (text, nome do produto)
      - `amount` (numeric, valor do pagamento)
      - `currency` (text, moeda)
      - `created_at` (timestamp, data de criação)
      - `updated_at` (timestamp, última atualização)

  2. Segurança
    - Habilitar RLS na tabela `payments`
    - Adicionar política para usuários autenticados lerem todos os dados
    - Adicionar política para usuários autenticados criarem/atualizarem dados
*/

CREATE TABLE IF NOT EXISTS payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bestfy_id text UNIQUE NOT NULL,
  customer_name text NOT NULL,
  customer_email text NOT NULL,
  customer_phone text DEFAULT '',
  product_name text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  currency text DEFAULT 'BRL',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read all payments"
  ON payments
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert payments"
  ON payments
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update payments"
  ON payments
  FOR UPDATE
  TO authenticated
  USING (true);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_payments_bestfy_id ON payments(bestfy_id);
CREATE INDEX IF NOT EXISTS idx_payments_customer_email ON payments(customer_email);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at DESC);