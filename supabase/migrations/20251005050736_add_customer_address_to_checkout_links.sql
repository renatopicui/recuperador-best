/*
  # Adicionar customer_address à tabela checkout_links

  1. Mudanças
    - Adiciona coluna customer_address (JSONB) para armazenar endereço do cliente
    - Permite NULL pois nem todas as transações têm endereço completo

  2. Notas
    - Campo é opcional mas será usado quando disponível
    - Formato JSON flexível para diferentes estruturas de endereço
*/

-- Adicionar coluna customer_address
ALTER TABLE checkout_links
ADD COLUMN IF NOT EXISTS customer_address JSONB;

-- Comentário para documentação
COMMENT ON COLUMN checkout_links.customer_address IS 'Endereço completo do cliente em formato JSON';
