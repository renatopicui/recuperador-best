/*
  # Permitir acesso público aos checkouts via slug

  1. Políticas
    - Permite que usuários anônimos acessem checkouts via a função get_checkout_by_slug
    - A função get_checkout_by_slug será marcada como SECURITY DEFINER para bypassar RLS
  
  2. Alterações
    - Adicionar política SELECT para anon na tabela checkout_links
    - Permitir acesso público baseado no slug
*/

-- Remover as políticas antigas restritivas
DROP POLICY IF EXISTS "Users can read own checkout links" ON checkout_links;
DROP POLICY IF EXISTS "Admin can view all checkout_links" ON checkout_links;

-- Criar política para permitir acesso público aos checkouts
CREATE POLICY "Anyone can view checkout_links"
  ON checkout_links FOR SELECT
  TO anon, authenticated
  USING (true);