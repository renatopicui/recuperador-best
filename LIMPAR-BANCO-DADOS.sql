-- ===================================================================
-- 🧹 LIMPAR BANCO DE DADOS - MANTER ESTRUTURA
-- ===================================================================
-- Remove todos os dados mas mantém tabelas, funções, triggers, etc.
-- ===================================================================

-- PASSO 1: Verificar dados ANTES da limpeza
SELECT '📊 ANTES DA LIMPEZA' as titulo;

SELECT 
    'payments' as tabela,
    COUNT(*)::text as total_registros
FROM payments
UNION ALL
SELECT 
    'checkout_links' as tabela,
    COUNT(*)::text as total_registros
FROM checkout_links
UNION ALL
SELECT 
    'api_keys' as tabela,
    COUNT(*)::text as total_registros
FROM api_keys
UNION ALL
SELECT 
    'profiles' as tabela,
    COUNT(*)::text as total_registros
FROM profiles
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles')
UNION ALL
SELECT 
    'auth.users' as tabela,
    COUNT(*)::text as total_registros
FROM auth.users;

-- ===================================================================
-- PASSO 2: LIMPAR TODAS AS TABELAS (respeitando foreign keys)
-- ===================================================================

-- Desabilitar verificação de foreign key temporariamente
SET session_replication_role = 'replica';

-- Limpar tabelas na ordem correta
TRUNCATE TABLE checkout_links CASCADE;
TRUNCATE TABLE payments CASCADE;
TRUNCATE TABLE api_keys CASCADE;

-- Limpar profiles se existir
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
        TRUNCATE TABLE profiles CASCADE;
        RAISE NOTICE '✅ Tabela profiles limpa';
    END IF;
END $$;

-- Reabilitar verificação de foreign key
SET session_replication_role = 'origin';

-- ===================================================================
-- PASSO 3: LIMPAR USUÁRIOS DO SUPABASE AUTH
-- ===================================================================

-- Deletar todas as identidades primeiro
DELETE FROM auth.identities;

-- Deletar todos os usuários
DELETE FROM auth.users;

-- ===================================================================
-- PASSO 4: VERIFICAR LIMPEZA
-- ===================================================================

SELECT '✅ APÓS LIMPEZA' as titulo;

SELECT 
    'payments' as tabela,
    COUNT(*)::text as total_registros,
    CASE WHEN COUNT(*) = 0 THEN '✅ LIMPO' ELSE '⚠️ AINDA TEM DADOS' END as status
FROM payments
UNION ALL
SELECT 
    'checkout_links' as tabela,
    COUNT(*)::text as total_registros,
    CASE WHEN COUNT(*) = 0 THEN '✅ LIMPO' ELSE '⚠️ AINDA TEM DADOS' END as status
FROM checkout_links
UNION ALL
SELECT 
    'api_keys' as tabela,
    COUNT(*)::text as total_registros,
    CASE WHEN COUNT(*) = 0 THEN '✅ LIMPO' ELSE '⚠️ AINDA TEM DADOS' END as status
FROM api_keys
UNION ALL
SELECT 
    'profiles' as tabela,
    COUNT(*)::text as total_registros,
    CASE WHEN COUNT(*) = 0 THEN '✅ LIMPO' ELSE '⚠️ AINDA TEM DADOS' END as status
FROM profiles
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles')
UNION ALL
SELECT 
    'auth.users' as tabela,
    COUNT(*)::text as total_registros,
    CASE WHEN COUNT(*) = 0 THEN '✅ LIMPO' ELSE '⚠️ AINDA TEM DADOS' END as status
FROM auth.users;

-- ===================================================================
-- PASSO 5: VERIFICAR ESTRUTURA (deve estar intacta)
-- ===================================================================

SELECT '📋 ESTRUTURA MANTIDA' as titulo;

SELECT 
    table_name as tabela,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name)::text as colunas,
    '✅ OK' as status
FROM information_schema.tables t
WHERE table_schema = 'public'
AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- ===================================================================
-- PASSO 6: VERIFICAR FUNÇÕES E TRIGGERS
-- ===================================================================

SELECT '🔧 FUNÇÕES' as tipo, COUNT(*)::text as quantidade
FROM information_schema.routines
WHERE routine_schema = 'public'
UNION ALL
SELECT '⚡ TRIGGERS' as tipo, COUNT(*)::text as quantidade
FROM information_schema.triggers
WHERE trigger_schema = 'public'
OR (event_object_schema = 'auth' AND event_object_table = 'users');

-- ===================================================================
-- ✅ RESULTADO ESPERADO:
-- ===================================================================
-- ANTES DA LIMPEZA:
--   - Várias linhas em cada tabela
-- 
-- APÓS LIMPEZA:
--   - 0 registros em todas as tabelas ✅
--   - Todas as tabelas: ✅ LIMPO
-- 
-- ESTRUTURA MANTIDA:
--   - Todas as tabelas existem ✅
--   - Todas as colunas preservadas ✅
--   - Funções e triggers intactos ✅
-- ===================================================================

-- ===================================================================
-- 🎯 PRÓXIMOS PASSOS:
-- ===================================================================
-- 1. Banco está limpo e pronto
-- 2. Estrutura completa mantida
-- 3. Agora você pode:
--    - Criar novo usuário via Sign Up
--    - Testar sistema do zero
--    - Começar fresh sem dados antigos
-- ===================================================================

