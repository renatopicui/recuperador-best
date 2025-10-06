/*
  # Fix Users List RLS Policy - DEFINITIVO

  1. Problema
    - Policy usando auth.jwt()->>'email' pode não funcionar
    - Precisamos usar auth.uid() que é mais confiável
    
  2. Solução
    - Drop política antiga
    - Criar nova política usando auth.uid()
    - Verificar se o usuário é o admin específico
*/

-- Drop política antiga
DROP POLICY IF EXISTS "Admin can read all users" ON users_list;

-- Criar nova política usando auth.uid()
CREATE POLICY "Admin can read all users"
  ON users_list
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = '4f106ef5-e0cd-40ae-bfed-32dc5661540d'::uuid
  );

-- Grant select to authenticated users
GRANT SELECT ON users_list TO authenticated;
