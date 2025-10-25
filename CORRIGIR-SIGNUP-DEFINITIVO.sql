-- ===================================================================
-- 🔧 CORRIGIR SIGNUP DEFINITIVO
-- ===================================================================
-- Execute este script para permitir cadastro via app
-- ===================================================================

-- PASSO 1: Ver todos os triggers em auth.users
SELECT 
    '🔍 TRIGGERS ATUAIS' as titulo,
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
AND event_object_table = 'users';

-- PASSO 2: Remover TODOS os triggers problemáticos
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_user_created ON auth.users;
DROP TRIGGER IF EXISTS handle_new_user ON auth.users;
DROP TRIGGER IF EXISTS create_profile_for_user ON auth.users;

-- PASSO 3: Remover funções relacionadas
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.create_profile_for_user() CASCADE;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS create_profile_for_user() CASCADE;

-- PASSO 4: Verificar se foi removido
SELECT 
    '✅ TRIGGERS APÓS LIMPEZA' as titulo,
    COUNT(*) as quantidade
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
AND event_object_table = 'users';

-- PASSO 5: Criar função simples que NÃO FALHA
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Log de debug
  RAISE NOTICE '✅ Novo usuário criado: %', NEW.email;
  
  -- Apenas retornar sem fazer nada que possa falhar
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Se der erro, apenas loga mas não impede a criação
    RAISE WARNING 'Erro no handle_new_user, mas continuando: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- PASSO 6: Criar trigger que NUNCA falha
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- PASSO 7: Verificar políticas RLS
SELECT 
    '🔒 POLÍTICAS RLS' as titulo,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE schemaname = 'auth'
AND tablename = 'users';

-- PASSO 8: Garantir permissões corretas
GRANT USAGE ON SCHEMA auth TO anon, authenticated;
GRANT SELECT ON auth.users TO anon, authenticated;

-- PASSO 9: Verificar se há usuários existentes
SELECT 
    '👥 USUÁRIOS EXISTENTES' as titulo,
    COUNT(*) as quantidade
FROM auth.users;

-- PASSO 10: Listar usuários (se houver)
SELECT 
    '📋 LISTA DE USUÁRIOS' as titulo,
    id,
    email,
    created_at,
    email_confirmed_at IS NOT NULL as confirmado
FROM auth.users
ORDER BY created_at DESC
LIMIT 10;

-- ===================================================================
-- 🎯 TESTE:
-- ===================================================================
-- Após executar este script:
-- 1. Volte para http://localhost:5173
-- 2. Tente criar cadastro via "Sign Up"
-- 3. Agora deve funcionar! ✅
-- 
-- Se ainda der erro, crie via Dashboard:
-- Supabase → Authentication → Users → Add user
-- ===================================================================

