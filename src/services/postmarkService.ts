import { supabase } from './supabaseService';

export interface EmailSettings {
  postmark_token: string;
  from_email: string;
  from_name: string;
  is_active: boolean;
}

export const postmarkService = {
  async saveSettings(settings: EmailSettings): Promise<void> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('User not authenticated');

    const { error } = await supabase
      .from('email_settings')
      .upsert({
        user_id: user.id,
        ...settings,
      }, {
        onConflict: 'user_id',
      });

    if (error) throw error;
  },

  async getSettings(): Promise<EmailSettings | null> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return null;

    const { data, error } = await supabase
      .from('email_settings')
      .select('postmark_token, from_email, from_name, is_active')
      .eq('user_id', user.id)
      .maybeSingle();

    if (error) throw error;
    return data;
  },

  async sendEmail(to: string, subject: string, html: string): Promise<void> {
    const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    const { data: { session } } = await supabase.auth.getSession();

    const response = await fetch(`${supabaseUrl}/functions/v1/postmark-proxy`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${session?.access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ to, subject, html }),
    });

    if (!response.ok) {
      throw new Error('Erro ao enviar email');
    }
  },
};
