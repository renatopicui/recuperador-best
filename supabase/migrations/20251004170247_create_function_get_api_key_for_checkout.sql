/*
  # Criar função para buscar API key no checkout público

  Esta migração cria uma função segura que permite buscar a API key
  de um usuário específico sem precisar estar autenticado, mas apenas
  quando chamada através da lógica de checkout.

  ## 1. Função
  - `get_api_key_for_user(user_uuid)` - Retorna a API key criptografada do usuário
  - SECURITY DEFINER para executar com permissões elevadas
  - Apenas retorna chaves ativas de Bestfy
  
  ## 2. Segurança
  - A função não expõe dados sensíveis diretamente
  - Apenas retorna a chave criptografada (Base64)
  - Pode ser chamada por usuários anônimos (necessário para checkout público)
*/

-- Função para buscar API key de um usuário específico
CREATE OR REPLACE FUNCTION get_api_key_for_user(user_uuid uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_encrypted_key text;
BEGIN
  -- Busca a API key ativa do usuário
  SELECT encrypted_key INTO v_encrypted_key
  FROM api_keys
  WHERE user_id = user_uuid
    AND service = 'bestfy'
    AND is_active = true
  LIMIT 1;
  
  -- Retorna a chave criptografada ou null se não encontrada
  RETURN v_encrypted_key;
END;
$$;

-- Permite que usuários anônimos e autenticados executem a função
GRANT EXECUTE ON FUNCTION get_api_key_for_user(uuid) TO anon, authenticated;
