import { supabase } from './supabaseService';

export interface UserSettings {
  id: string;
  user_id: string;
  recovery_email_delay_minutes: number;
  created_at: string;
  updated_at: string;
}

export const settingsService = {
  /**
   * Buscar configurações do usuário atual
   */
  async getUserSettings(): Promise<UserSettings | null> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('User not authenticated');

    const { data, error } = await supabase
      .from('user_settings')
      .select('*')
      .eq('user_id', user.id)
      .single();

    if (error && error.code !== 'PGRST116') { // PGRST116 = no rows returned
      console.error('Erro ao buscar configurações:', error);
      throw error;
    }

    return data;
  },

  /**
   * Criar ou atualizar configurações do usuário
   */
  async saveUserSettings(settings: { recovery_email_delay_minutes: number }): Promise<UserSettings> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('User not authenticated');

    // Validar valor
    if (settings.recovery_email_delay_minutes < 1 || settings.recovery_email_delay_minutes > 60) {
      throw new Error('O tempo deve estar entre 1 e 60 minutos');
    }

    // Tentar buscar configuração existente
    const existing = await this.getUserSettings();

    let result;
    if (existing) {
      // Atualizar
      const { data, error } = await supabase
        .from('user_settings')
        .update({
          recovery_email_delay_minutes: settings.recovery_email_delay_minutes,
        })
        .eq('user_id', user.id)
        .select()
        .single();

      if (error) throw error;
      result = data;
    } else {
      // Criar
      const { data, error } = await supabase
        .from('user_settings')
        .insert({
          user_id: user.id,
          recovery_email_delay_minutes: settings.recovery_email_delay_minutes,
        })
        .select()
        .single();

      if (error) throw error;
      result = data;
    }

    return result;
  },

  /**
   * Obter valor padrão se não houver configuração
   */
  getDefaultSettings(): Partial<UserSettings> {
    return {
      recovery_email_delay_minutes: 3,
    };
  },
};

