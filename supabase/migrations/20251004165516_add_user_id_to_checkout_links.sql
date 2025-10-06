/*
  # Adicionar user_id à tabela checkout_links

  Esta migração adiciona o campo user_id à tabela checkout_links para permitir
  que o sistema identifique qual API key usar ao criar transações PIX no checkout.

  ## 1. Mudanças
  - Adiciona coluna `user_id` (uuid, foreign key para auth.users)
  - Cria índice para melhorar performance de queries por user_id
  
  ## 2. Segurança
  - RLS continua ativo
  - Políticas existentes continuam válidas
*/

-- Adiciona coluna user_id
ALTER TABLE checkout_links ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

-- Cria índice para performance
CREATE INDEX IF NOT EXISTS idx_checkout_links_user_id ON checkout_links(user_id);

-- Comentário para documentação
COMMENT ON COLUMN checkout_links.user_id IS 'ID do usuário que criou o link de checkout (para buscar API key)';
