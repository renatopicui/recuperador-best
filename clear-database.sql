-- ============================================
-- Script para Limpar Banco de Dados
-- Mantém a estrutura das tabelas, remove apenas os dados
-- ============================================

-- Desabilitar temporariamente as verificações de foreign key
SET session_replication_role = 'replica';

-- Limpar tabelas na ordem correta (respeitar foreign keys)
TRUNCATE TABLE checkout_links CASCADE;
TRUNCATE TABLE payments CASCADE;
TRUNCATE TABLE api_keys CASCADE;

-- Limpar usuários do Supabase Auth
-- ATENÇÃO: Isso vai remover TODOS os usuários cadastrados
DELETE FROM auth.users;

-- Reabilitar as verificações de foreign key
SET session_replication_role = 'origin';

-- Verificar se as tabelas estão vazias
SELECT 'checkout_links' as tabela, COUNT(*) as registros FROM checkout_links
UNION ALL
SELECT 'payments' as tabela, COUNT(*) as registros FROM payments
UNION ALL
SELECT 'api_keys' as tabela, COUNT(*) as registros FROM api_keys
UNION ALL
SELECT 'auth.users' as tabela, COUNT(*) as registros FROM auth.users;

