/*
  # Permitir operações em pagamentos sem user_id
  
  1. Alterações
    - Adicionar política para SELECT em pagamentos com user_id NULL
    - Adicionar política para INSERT em pagamentos com user_id NULL
    - Adicionar política para UPDATE em pagamentos com user_id NULL
    - Isso permite que webhooks criem/atualizem pagamentos antes de associá-los a usuários
  
  2. Segurança
    - Políticas existentes continuam protegendo pagamentos com user_id definido
    - Apenas Service Role pode acessar pagamentos sem user_id
*/

-- Permite SELECT em pagamentos sem user_id associado
CREATE POLICY "Service can view unassigned payments"
  ON payments FOR SELECT
  USING (user_id IS NULL);

-- Permite INSERT em pagamentos sem user_id associado
CREATE POLICY "Service can insert unassigned payments"
  ON payments FOR INSERT
  WITH CHECK (user_id IS NULL);

-- Permite UPDATE em pagamentos sem user_id associado
CREATE POLICY "Service can update unassigned payments"
  ON payments FOR UPDATE
  USING (user_id IS NULL)
  WITH CHECK (true);