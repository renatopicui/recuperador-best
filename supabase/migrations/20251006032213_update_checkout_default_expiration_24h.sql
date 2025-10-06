/*
  # Atualizar default do expires_at para 24 horas

  1. Alterações
    - Modificar o default da coluna expires_at na tabela checkout_links
    - Mudar de qualquer valor anterior para 24 horas
*/

-- Alterar o default da coluna expires_at para 24 horas
ALTER TABLE checkout_links 
ALTER COLUMN expires_at SET DEFAULT (NOW() + INTERVAL '24 hours');