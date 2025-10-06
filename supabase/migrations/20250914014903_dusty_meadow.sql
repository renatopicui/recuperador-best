/*
  # Adicionar coluna user_id na tabela api_keys

  1. Modificações na tabela
    - Adicionar coluna `user_id` (uuid, foreign key para auth.users)
    - Adicionar índice para performance
    - Atualizar políticas RLS para filtrar por usuário

  2. Segurança
    - RLS habilitado para isolamento por usuário
    - Políticas atualizadas para usar user_id
*/

-- Adicionar coluna user_id se não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'api_keys' AND column_name = 'user_id'
  ) THEN
    ALTER TABLE api_keys ADD COLUMN user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Criar índice para performance
CREATE INDEX IF NOT EXISTS idx_api_keys_user_id ON api_keys(user_id);

-- Remover políticas antigas
DROP POLICY IF EXISTS "Allow anon users to manage API keys" ON api_keys;
DROP POLICY IF EXISTS "Allow authenticated users to manage API keys" ON api_keys;

-- Criar novas políticas baseadas em user_id
CREATE POLICY "Users can manage their own API keys"
  ON api_keys
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);