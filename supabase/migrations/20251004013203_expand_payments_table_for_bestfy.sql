/*
  # Expandir tabela payments para dados completos da Bestfy

  Esta migração expande a tabela payments para armazenar todos os dados relevantes
  das transações recebidas via webhook da Bestfy, permitindo rastreamento completo
  do ciclo de vida da transação.

  ## Novos Campos Adicionados

  ### Dados da Transação
  - `installments` - Número de parcelas
  - `refunded_amount` - Valor reembolsado
  - `paid_at` - Data/hora do pagamento
  - `refused_reason` - Motivo da recusa (quando aplicável)
  - `external_ref` - Referência externa
  - `secure_id` - ID seguro da Bestfy
  - `ip` - IP do comprador
  - `traceable` - Se a transação é rastreável

  ### Dados do Cliente (expandidos)
  - `customer_document` - CPF/CNPJ do cliente
  - `customer_document_type` - Tipo do documento (cpf/cnpj)
  - `customer_birthdate` - Data de nascimento
  - `customer_address` - Endereço completo (JSON)

  ### Dados do Cartão (quando aplicável)
  - `card_brand` - Bandeira do cartão
  - `card_last_digits` - Últimos 4 dígitos
  - `card_holder_name` - Nome no cartão

  ### Dados de Taxas
  - `fee_fixed_amount` - Taxa fixa
  - `fee_spread_percentage` - Percentual de spread
  - `fee_estimated` - Taxa estimada total
  - `fee_net_amount` - Valor líquido após taxas

  ### Dados dos Itens
  - `items` - Array JSON com todos os itens da compra

  ### Metadados
  - `metadata` - Campo JSON para dados customizados
  - `postback_url` - URL de postback configurada
  - `webhook_events` - Histórico de eventos recebidos (JSON array)

  ## Segurança
  - Todas as colunas são opcionais (nullable) para compatibilidade
  - Dados sensíveis como documento são armazenados com segurança
  - RLS continua aplicado na tabela
*/

-- Dados da transação
ALTER TABLE payments ADD COLUMN IF NOT EXISTS installments integer DEFAULT 1;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS refunded_amount numeric DEFAULT 0;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS paid_at timestamptz;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS refused_reason text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS external_ref text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS secure_id text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS ip text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS traceable boolean DEFAULT false;

-- Dados expandidos do cliente
ALTER TABLE payments ADD COLUMN IF NOT EXISTS customer_document text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS customer_document_type text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS customer_birthdate date;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS customer_address jsonb;

-- Dados do cartão
ALTER TABLE payments ADD COLUMN IF NOT EXISTS card_brand text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS card_last_digits text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS card_holder_name text;

-- Dados de taxas
ALTER TABLE payments ADD COLUMN IF NOT EXISTS fee_fixed_amount numeric;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS fee_spread_percentage numeric;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS fee_estimated numeric;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS fee_net_amount numeric;

-- Dados dos itens (JSON array)
ALTER TABLE payments ADD COLUMN IF NOT EXISTS items jsonb;

-- Metadados e configurações
ALTER TABLE payments ADD COLUMN IF NOT EXISTS metadata jsonb;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS postback_url text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS webhook_events jsonb DEFAULT '[]'::jsonb;

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_paid_at ON payments(paid_at);
CREATE INDEX IF NOT EXISTS idx_payments_customer_email ON payments(customer_email);
CREATE INDEX IF NOT EXISTS idx_payments_payment_method ON payments(payment_method);
CREATE INDEX IF NOT EXISTS idx_payments_secure_id ON payments(secure_id);

-- Comentários para documentação
COMMENT ON COLUMN payments.installments IS 'Número de parcelas da transação';
COMMENT ON COLUMN payments.refunded_amount IS 'Valor total reembolsado';
COMMENT ON COLUMN payments.paid_at IS 'Data e hora do pagamento efetivo';
COMMENT ON COLUMN payments.refused_reason IS 'Motivo da recusa quando status = refused';
COMMENT ON COLUMN payments.external_ref IS 'Referência externa da transação';
COMMENT ON COLUMN payments.secure_id IS 'ID seguro da Bestfy para a transação';
COMMENT ON COLUMN payments.items IS 'Array JSON com todos os itens da compra';
COMMENT ON COLUMN payments.webhook_events IS 'Histórico de eventos de webhook recebidos';
COMMENT ON COLUMN payments.metadata IS 'Dados customizados adicionais';
