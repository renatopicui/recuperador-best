-- Adiciona coluna company_id na tabela api_keys para mapear usuários
ALTER TABLE api_keys ADD COLUMN IF NOT EXISTS company_id text;

-- Adiciona índice para busca rápida por company_id
CREATE INDEX IF NOT EXISTS idx_api_keys_company_id ON api_keys(company_id) WHERE company_id IS NOT NULL;

-- Comentário explicativo
COMMENT ON COLUMN api_keys.company_id IS 'Company ID da Bestfy para identificar o usuário proprietário das transações';
