/*
  # Adicionar Desconto aos Checkouts de Recuperação

  1. Mudanças
    - Adiciona coluna `original_amount` para armazenar valor original
    - Adiciona coluna `discount_amount` para armazenar valor do desconto
    - Adiciona coluna `final_amount` para armazenar valor final com desconto
    - Adiciona coluna `discount_percentage` para armazenar % de desconto (padrão 20%)

  2. Notas
    - Todos os checkouts de recuperação terão 20% de desconto automaticamente
    - Valores são armazenados para histórico e auditoria
*/

-- Adicionar colunas de desconto à tabela checkout_links
ALTER TABLE checkout_links
ADD COLUMN IF NOT EXISTS original_amount DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS discount_percentage DECIMAL(5, 2) DEFAULT 20.00,
ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS final_amount DECIMAL(10, 2);

-- Comentários nas colunas para documentação
COMMENT ON COLUMN checkout_links.original_amount IS 'Valor original do produto sem desconto';
COMMENT ON COLUMN checkout_links.discount_percentage IS 'Percentual de desconto aplicado (padrão 20%)';
COMMENT ON COLUMN checkout_links.discount_amount IS 'Valor do desconto em reais';
COMMENT ON COLUMN checkout_links.final_amount IS 'Valor final após aplicar desconto';
