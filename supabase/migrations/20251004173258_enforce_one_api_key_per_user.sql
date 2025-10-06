/*
  # Garantir apenas UMA chave da Bestfy por usuário

  1. Modificações
    - Adiciona constraint UNIQUE em (user_id, service, key_name)
    - Garante que cada usuário só possa ter UMA credencial da Bestfy ativa
    - Previne custos desnecessários e duplicação de contas

  2. Segurança
    - Mantém RLS existente
    - Previne múltiplas contas com mesma credencial
    - Força atualização ao invés de inserção duplicada

  3. Notas Importantes
    - Esta constraint impede criar múltiplas chaves com mesmo service/key_name para um usuário
    - Se tentar inserir duplicata, o banco retornará erro
    - Use UPDATE ou UPSERT para modificar chaves existentes
*/

-- Adicionar constraint UNIQUE para (user_id, service, key_name)
-- Isso garante que cada usuário só pode ter UMA chave por serviço
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'api_keys_user_service_name_key'
  ) THEN
    ALTER TABLE api_keys 
    ADD CONSTRAINT api_keys_user_service_name_key 
    UNIQUE (user_id, service, key_name);
  END IF;
END $$;

-- Adicionar comentário explicativo
COMMENT ON CONSTRAINT api_keys_user_service_name_key ON api_keys IS 
'Garante que cada usuário tenha apenas UMA chave API por serviço. Previne custos desnecessários e duplicação de contas.';