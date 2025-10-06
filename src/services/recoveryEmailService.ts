import { supabase } from './supabaseService';

export const recoveryEmailService = {
  async sendRecoveryEmails(): Promise<{ sent: number; failed: number }> {
    const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    const { data: { session } } = await supabase.auth.getSession();

    const response = await fetch(`${supabaseUrl}/functions/v1/send-recovery-emails`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${session?.access_token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      throw new Error('Erro ao enviar emails de recuperação');
    }

    return await response.json();
  },
};
