/*
  # Adicionar status à tabela checkout_links

  1. Mudanças
    - Adiciona coluna status para rastrear estado do checkout
    - Valores possíveis: 'pending' (aguardando PIX), 'active' (PIX gerado), 'expired', 'completed'

  2. Notas
    - Status default é 'pending'
    - Muda para 'active' quando PIX é gerado
*/

-- Adicionar coluna status
ALTER TABLE checkout_links
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';

-- Comentário para documentação
COMMENT ON COLUMN checkout_links.status IS 'Status do checkout: pending (aguardando), active (PIX gerado), expired, completed';
