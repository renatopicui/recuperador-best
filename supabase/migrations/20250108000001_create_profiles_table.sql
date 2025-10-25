-- Criar tabela de perfis para dados adicionais dos usuários
CREATE TABLE IF NOT EXISTS public.profiles (
    -- user_id será a chave primária e Foreign Key para auth.users
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY, 
    
    -- Campos solicitados
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    
    -- Outros campos padrão
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar RLS (Row Level Security)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Políticas de segurança
-- Usuários podem ver apenas seu próprio perfil
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

-- Service role pode inserir (usado pelo trigger)
CREATE POLICY "Service role can insert profiles"
    ON public.profiles FOR INSERT
    TO service_role
    WITH CHECK (true);

-- Usuários podem atualizar apenas seu próprio perfil
CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Admin pode ver todos os perfis
CREATE POLICY "Admin can view all profiles"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (
        (SELECT email FROM auth.users WHERE id = auth.uid()) = 'adm@bestfybr.com.br'
    );

-- Criar índice para busca rápida
CREATE INDEX IF NOT EXISTS idx_profiles_full_name ON public.profiles(full_name);
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON public.profiles(phone);

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Comentários
COMMENT ON TABLE public.profiles IS 'Perfis dos usuários com dados adicionais não armazenados em auth.users';
COMMENT ON COLUMN public.profiles.full_name IS 'Nome completo do usuário';
COMMENT ON COLUMN public.profiles.phone IS 'Telefone do usuário com DDD';

-- ========================================
-- TRIGGER AUTOMÁTICO PARA CRIAR PERFIL
-- ========================================

-- Função que cria perfil automaticamente quando usuário é criado
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, phone)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', ''),
    COALESCE(new.raw_user_meta_data->>'phone', '')
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger que executa após inserir usuário
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

COMMENT ON FUNCTION public.handle_new_user IS 'Cria automaticamente o perfil do usuário com dados do raw_user_meta_data';

