-- ========================================
-- CRIAR TABELA DE CONFIGURAÇÕES POR USUÁRIO
-- ========================================

-- Criar tabela user_settings
CREATE TABLE IF NOT EXISTS public.user_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Tempo em minutos para enviar email de recuperação
    recovery_email_delay_minutes INTEGER NOT NULL DEFAULT 3 CHECK (recovery_email_delay_minutes BETWEEN 1 AND 60),
    
    -- Outros campos úteis
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    
    -- Garantir que cada usuário tenha apenas uma configuração
    UNIQUE(user_id)
);

-- Habilitar RLS
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

-- Políticas RLS
-- Usuários podem ler apenas suas próprias configurações
CREATE POLICY "Users can view own settings"
    ON public.user_settings
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- Usuários podem inserir apenas suas próprias configurações
CREATE POLICY "Users can insert own settings"
    ON public.user_settings
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Usuários podem atualizar apenas suas próprias configurações
CREATE POLICY "Users can update own settings"
    ON public.user_settings
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Service role pode fazer tudo (para Edge Functions)
CREATE POLICY "Service role can manage all settings"
    ON public.user_settings
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Criar função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_user_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger
DROP TRIGGER IF EXISTS set_user_settings_updated_at ON public.user_settings;
CREATE TRIGGER set_user_settings_updated_at
    BEFORE UPDATE ON public.user_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_user_settings_updated_at();

-- Criar índice para busca rápida
CREATE INDEX IF NOT EXISTS idx_user_settings_user_id ON public.user_settings(user_id);

-- Comentários
COMMENT ON TABLE public.user_settings IS 'Configurações personalizadas por usuário';
COMMENT ON COLUMN public.user_settings.recovery_email_delay_minutes IS 'Tempo em minutos para enviar email de recuperação (1-60)';

-- Criar função para obter ou criar configuração padrão
CREATE OR REPLACE FUNCTION get_or_create_user_settings(p_user_id UUID)
RETURNS public.user_settings AS $$
DECLARE
    v_settings public.user_settings;
BEGIN
    -- Tentar buscar configuração existente
    SELECT * INTO v_settings
    FROM public.user_settings
    WHERE user_id = p_user_id;
    
    -- Se não existir, criar com valores padrão
    IF v_settings IS NULL THEN
        INSERT INTO public.user_settings (user_id, recovery_email_delay_minutes)
        VALUES (p_user_id, 3)
        RETURNING * INTO v_settings;
    END IF;
    
    RETURN v_settings;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- FIM DA MIGRAÇÃO
-- ========================================

