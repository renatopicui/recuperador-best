import { supabase } from './supabaseService';

export const apiKeyService = {
  async saveApiKey(apiKey: string): Promise<void> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('User not authenticated');

    const testResponse = await fetch('https://api.bestfy.com.br/v1/account', {
      headers: {
        'Authorization': `Bearer ${apiKey}`,
      },
    });

    if (!testResponse.ok) {
      throw new Error('Chave API inválida');
    }

    const { error } = await supabase
      .from('api_keys')
      .upsert({
        user_id: user.id,
        encrypted_key: apiKey,
        service: 'bestfy',
        key_name: 'default',
        is_active: true,
      }, {
        onConflict: 'user_id,service,key_name',
      });

    if (error) throw error;
  },

  async getApiKey(): Promise<string | null> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return null;

    const { data, error } = await supabase
      .from('api_keys')
      .select('encrypted_key')
      .eq('user_id', user.id)
      .eq('is_active', true)
      .maybeSingle();

    if (error) throw error;
    return data?.encrypted_key || null;
  },
};
