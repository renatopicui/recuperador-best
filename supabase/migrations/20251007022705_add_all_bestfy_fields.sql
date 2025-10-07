/*
  # Adicionar TODOS os campos da Bestfy à tabela payments

  Esta migração adiciona todos os campos restantes que a Bestfy envia via webhook
  e que não estavam sendo salvos anteriormente.

  ## 1. Novos Campos Adicionados

  ### Dados da Empresa e Transação
  - `company_id` - ID da empresa na Bestfy
  
  ### Dados Completos do Cliente
  - `customer_id` - ID do cliente na Bestfy
  - `customer_external_ref` - Referência externa do cliente
  - `customer_created_at` - Data de criação do cliente na Bestfy
  
  ### Dados Completos do Cartão
  - `card_id` - ID do cartão na Bestfy
  - `card_expiration_month` - Mês de validade
  - `card_expiration_year` - Ano de validade
  - `card_reusable` - Se o cartão pode ser reutilizado
  - `card_created_at` - Data de criação do cartão na Bestfy
  
  ### Dados de Métodos de Pagamento Específicos
  - `boleto_data` - Dados completos do boleto (JSONB)
  - `pix_data` - Dados completos do PIX incluindo QR code (JSONB)
  
  ### Dados de Envio e Entrega
  - `shipping_data` - Dados de frete/envio (JSONB)
  - `delivery_data` - Dados de entrega (JSONB)
  
  ### Dados Financeiros Avançados
  - `splits` - Divisão de pagamento entre recipientes (JSONB array)
  - `refunds` - Histórico completo de reembolsos (JSONB array)

  ## 2. Índices para Performance
  - Índice no customer_id para buscas rápidas
  - Índice no company_id para filtros por empresa

  ## 3. Segurança
  - RLS permanece ativo na tabela
  - Todos os campos são nullable para compatibilidade
*/

-- Dados da empresa
ALTER TABLE payments ADD COLUMN IF NOT EXISTS company_id integer;

-- Dados completos do cliente
ALTER TABLE payments ADD COLUMN IF NOT EXISTS customer_id integer;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS customer_external_ref text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS customer_created_at timestamptz;

-- Dados completos do cartão
ALTER TABLE payments ADD COLUMN IF NOT EXISTS card_id integer;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS card_expiration_month integer;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS card_expiration_year integer;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS card_reusable boolean;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS card_created_at timestamptz;

-- Dados de métodos de pagamento específicos (JSON para flexibilidade)
ALTER TABLE payments ADD COLUMN IF NOT EXISTS boleto_data jsonb;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS pix_data jsonb;

-- Dados de envio e entrega
ALTER TABLE payments ADD COLUMN IF NOT EXISTS shipping_data jsonb;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS delivery_data jsonb;

-- Dados financeiros avançados
ALTER TABLE payments ADD COLUMN IF NOT EXISTS splits jsonb;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS refunds jsonb;

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_payments_customer_id ON payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_payments_company_id ON payments(company_id);
CREATE INDEX IF NOT EXISTS idx_payments_card_id ON payments(card_id);

-- Comentários para documentação
COMMENT ON COLUMN payments.company_id IS 'ID da empresa na Bestfy';
COMMENT ON COLUMN payments.customer_id IS 'ID do cliente na Bestfy';
COMMENT ON COLUMN payments.customer_external_ref IS 'Referência externa do cliente';
COMMENT ON COLUMN payments.customer_created_at IS 'Data de criação do cliente na Bestfy';
COMMENT ON COLUMN payments.card_id IS 'ID do cartão na Bestfy';
COMMENT ON COLUMN payments.card_expiration_month IS 'Mês de validade do cartão (1-12)';
COMMENT ON COLUMN payments.card_expiration_year IS 'Ano de validade do cartão';
COMMENT ON COLUMN payments.card_reusable IS 'Se o cartão pode ser reutilizado em outras compras';
COMMENT ON COLUMN payments.card_created_at IS 'Data de criação/cadastro do cartão na Bestfy';
COMMENT ON COLUMN payments.boleto_data IS 'Dados completos do boleto em formato JSON';
COMMENT ON COLUMN payments.pix_data IS 'Dados completos do PIX incluindo QR code em formato JSON';
COMMENT ON COLUMN payments.shipping_data IS 'Dados de frete/envio em formato JSON';
COMMENT ON COLUMN payments.delivery_data IS 'Dados de entrega em formato JSON';
COMMENT ON COLUMN payments.splits IS 'Array JSON com divisão de pagamento entre recipientes';
COMMENT ON COLUMN payments.refunds IS 'Array JSON com histórico completo de reembolsos';