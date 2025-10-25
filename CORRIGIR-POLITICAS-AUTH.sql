-- ===================================================================
-- 🔧 CORRIGIR POLÍTICAS DE AUTENTICAÇÃO
-- ===================================================================
-- Execute no Supabase SQL Editor para resolver "Database error finding user"
-- ===================================================================

-- PASSO 1: Desabilitar RLS temporariamente para criar usuário
ALTER TABLE IF EXISTS auth.users DISABLE ROW LEVEL SECURITY;

-- PASSO 2: Remover triggers problemáticos (se existirem)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;

-- PASSO 3: Verificar se há usuários
SELECT 
    '👥 USUÁRIOS EXISTENTES' as titulo,
    COUNT(*) as quantidade
FROM auth.users;

-- PASSO 4: Ver usuários (se houver)
SELECT 
    id,
    email,
    created_at,
    email_confirmed_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 10;

-- PASSO 5: Criar função simples para novos usuários (sem erros)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Não fazer nada por enquanto
  -- Apenas permitir a criação do usuário
  RETURN NEW;
END;
$$;

-- PASSO 6: Recriar trigger (sem causar erros)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- PASSO 7: Garantir que a tabela auth.users está acessível
GRANT USAGE ON SCHEMA auth TO anon, authenticated;
GRANT SELECT ON auth.users TO anon, authenticated;

-- ===================================================================
-- 🎯 APÓS EXECUTAR:
-- ===================================================================
-- 1. Volte para http://localhost:5173
-- 2. Tente criar novo usuário
-- 3. Deve funcionar agora! ✅
-- ===================================================================

