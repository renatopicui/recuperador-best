-- ===================================================================
-- 🔐 CRIAR USUÁRIO NO SUPABASE
-- ===================================================================
-- Execute no Supabase SQL Editor para criar um usuário
-- ===================================================================

-- OPÇÃO 1: Ver usuários existentes
SELECT 
    '👥 USUÁRIOS CADASTRADOS' as titulo,
    id,
    email,
    created_at,
    last_sign_in_at,
    email_confirmed_at
FROM auth.users
ORDER BY created_at DESC;

-- ===================================================================
-- OPÇÃO 2: Criar novo usuário (SE NÃO HOUVER NENHUM)
-- ===================================================================
-- ATENÇÃO: Altere o email e senha abaixo!
-- ===================================================================

-- Inserir usuário diretamente (apenas para desenvolvimento)
INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'seu-email@exemplo.com',  -- ALTERAR AQUI
    crypt('sua-senha-123', gen_salt('bf')),  -- ALTERAR AQUI
    NOW(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
);

-- Criar identidade para o usuário
INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
)
SELECT 
    gen_random_uuid(),
    id,
    format('{"sub":"%s","email":"%s"}', id::text, email)::jsonb,
    'email',
    NOW(),
    NOW(),
    NOW()
FROM auth.users
WHERE email = 'seu-email@exemplo.com'  -- ALTERAR AQUI
AND NOT EXISTS (
    SELECT 1 FROM auth.identities WHERE user_id = auth.users.id
);

-- Verificar se foi criado
SELECT 
    '✅ VERIFICAÇÃO' as titulo,
    id,
    email,
    email_confirmed_at,
    created_at
FROM auth.users
WHERE email = 'seu-email@exemplo.com'  -- ALTERAR AQUI
ORDER BY created_at DESC;

-- ===================================================================
-- 📋 INSTRUÇÕES:
-- ===================================================================
-- 1. ALTERE "seu-email@exemplo.com" para seu email real
-- 2. ALTERE "sua-senha-123" para uma senha de sua escolha
-- 3. Execute o script completo
-- 4. Veja se o usuário foi criado na última consulta
-- 5. Volte para http://localhost:5173 e faça login
-- ===================================================================

