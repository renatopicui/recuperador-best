-- ===================================================================
-- 👤 CRIAR USUÁRIO DIRETAMENTE NO BANCO
-- ===================================================================
-- Use este método se o cadastro via interface ainda não funcionar
-- ===================================================================

-- PASSO 1: Ver usuários existentes
SELECT 
    '👥 USUÁRIOS ATUAIS' as titulo,
    id,
    email,
    created_at
FROM auth.users
ORDER BY created_at DESC;

-- PASSO 2: Deletar usuários de teste (SE NECESSÁRIO)
-- DELETE FROM auth.users WHERE email LIKE '%@teste.com';

-- PASSO 3: Criar usuário administrador
-- ALTERE o email e senha abaixo!

DO $$
DECLARE
    new_user_id uuid := gen_random_uuid();
    new_email text := 'admin@teste.com';  -- ALTERAR AQUI
    new_password text := 'senha123';       -- ALTERAR AQUI
BEGIN
    -- Inserir usuário
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        recovery_sent_at,
        last_sign_in_at,
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
        new_user_id,
        'authenticated',
        'authenticated',
        new_email,
        crypt(new_password, gen_salt('bf')),
        NOW(),
        NOW(),
        NOW(),
        '{"provider":"email","providers":["email"]}',
        '{}',
        NOW(),
        NOW(),
        '',
        '',
        '',
        ''
    )
    ON CONFLICT (id) DO NOTHING;

    -- Criar identidade
    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        last_sign_in_at,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        new_user_id,
        format('{"sub":"%s","email":"%s"}', new_user_id::text, new_email)::jsonb,
        'email',
        NOW(),
        NOW(),
        NOW()
    )
    ON CONFLICT (provider, id) DO NOTHING;

    RAISE NOTICE '✅ Usuário criado: %', new_email;
    RAISE NOTICE '🔑 Senha: %', new_password;
    RAISE NOTICE '🆔 ID: %', new_user_id;
END $$;

-- PASSO 4: Verificar se foi criado
SELECT 
    '✅ VERIFICAÇÃO' as titulo,
    id,
    email,
    email_confirmed_at IS NOT NULL as email_confirmado,
    created_at
FROM auth.users
WHERE email = 'admin@teste.com'  -- ALTERAR AQUI
ORDER BY created_at DESC;

-- PASSO 5: Ver TODOS os usuários criados
SELECT 
    '📋 TODOS OS USUÁRIOS' as titulo,
    email,
    email_confirmed_at IS NOT NULL as confirmado,
    created_at,
    last_sign_in_at
FROM auth.users
ORDER BY created_at DESC;

-- ===================================================================
-- 🎯 CREDENCIAIS CRIADAS:
-- ===================================================================
-- Email: admin@teste.com (ou o que você alterou)
-- Senha: senha123 (ou a que você alterou)
-- 
-- Use estas credenciais para fazer login em:
-- http://localhost:5173
-- ===================================================================

