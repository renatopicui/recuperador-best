/*
  # Tornar user_id opcional na tabela payments
  
  1. Alterações
    - Modificar coluna `user_id` para aceitar NULL
    - Isso permite que webhooks da Bestfy salvem pagamentos sem associação com usuário
    - Futuramente, um processo pode associar pagamentos aos usuários corretos
  
  2. Segurança
    - Manter políticas RLS existentes
    - Usuários continuam vendo apenas seus próprios pagamentos
*/

ALTER TABLE payments 
ALTER COLUMN user_id DROP NOT NULL;