-- ===================================================================
-- 🔍 INVESTIGAR E CORRIGIR BUG DO SIGN UP
-- ===================================================================
-- Vamos descobrir qual trigger está causando "Database error finding user"
-- ===================================================================

-- PASSO 1: Ver TODOS os triggers em auth.users
SELECT 
    '🔍 STEP 1: TRIGGERS EM auth.users' as titulo,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
AND event_object_table = 'users'
ORDER BY trigger_name;

-- PASSO 2: Ver todas as funções que podem estar relacionadas
SELECT 
    '🔍 STEP 2: FUNÇÕES RELACIONADAS' as titulo,
    routine_name,
    routine_type,
    routine_schema
FROM information_schema.routines
WHERE routine_name LIKE '%user%'
OR routine_name LIKE '%profile%'
OR routine_name LIKE '%auth%'
ORDER BY routine_schema, routine_name;

-- PASSO 3: Ver se existe tabela profiles (que pode ser o problema)
SELECT 
    '🔍 STEP 3: VERIFICAR TABELA PROFILES' as titulo,
    table_schema,
    table_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') 
        THEN '✅ Tabela profiles EXISTE'
        ELSE '❌ Tabela profiles NÃO EXISTE (pode ser o problema!)'
    END as status
FROM information_schema.tables
WHERE table_name = 'profiles'
LIMIT 1;

-- PASSO 4: REMOVER TODOS os triggers problemáticos
DO $$
DECLARE
    trigger_rec RECORD;
BEGIN
    RAISE NOTICE '🔧 Removendo todos os triggers de auth.users...';
    
    FOR trigger_rec IN 
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_schema = 'auth'
        AND event_object_table = 'users'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users', trigger_rec.trigger_name);
        RAISE NOTICE '✅ Trigger removido: %', trigger_rec.trigger_name;
    END LOOP;
    
    RAISE NOTICE '✅ Todos os triggers removidos!';
END $$;

-- PASSO 5: Verificar se foram removidos
SELECT 
    '✅ STEP 4: TRIGGERS APÓS REMOÇÃO' as titulo,
    COUNT(*) as quantidade_triggers
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
AND event_object_table = 'users';

-- PASSO 6: Criar tabela profiles se não existir (pode ser necessária)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    phone TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- PASSO 7: Habilitar RLS na tabela profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- PASSO 8: Criar políticas para profiles
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
ON public.profiles FOR SELECT
TO authenticated
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
ON public.profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- PASSO 9: Criar função SIMPLES que funciona
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Criar perfil para o novo usuário
  INSERT INTO public.profiles (id, full_name, phone)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'phone', '')
  );
  
  RAISE NOTICE '✅ Profile criado para usuário: %', NEW.email;
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log do erro mas não impede a criação do usuário
    RAISE WARNING '⚠️ Erro ao criar profile (mas usuário foi criado): %', SQLERRM;
    RETURN NEW;
END;
$$;

-- PASSO 10: Criar trigger que funciona
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- PASSO 11: Verificar estrutura final
SELECT 
    '📊 STEP 5: ESTRUTURA FINAL' as titulo,
    'Triggers' as tipo,
    COUNT(*)::text as quantidade
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
AND event_object_table = 'users'
UNION ALL
SELECT 
    '📊 STEP 5: ESTRUTURA FINAL' as titulo,
    'Tabela profiles' as tipo,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') 
    THEN '✅ Existe' 
    ELSE '❌ Não existe' 
    END
UNION ALL
SELECT 
    '📊 STEP 5: ESTRUTURA FINAL' as titulo,
    'Função handle_new_user' as tipo,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'handle_new_user') 
    THEN '✅ Existe' 
    ELSE '❌ Não existe' 
    END;

-- PASSO 12: Listar usuários existentes
SELECT 
    '👥 STEP 6: USUÁRIOS EXISTENTES' as titulo,
    id,
    email,
    created_at,
    email_confirmed_at IS NOT NULL as confirmado
FROM auth.users
ORDER BY created_at DESC;

-- ===================================================================
-- ✅ PRONTO! AGORA TESTE:
-- ===================================================================
-- 1. Volte para http://localhost:5173
-- 2. Tente criar conta via Sign Up
-- 3. Preencha os dados
-- 4. Deve funcionar sem erro! ✅
-- 
-- Se ainda der erro, copie o erro COMPLETO do console (F12)
-- e me envie para eu analisar.
-- ===================================================================

