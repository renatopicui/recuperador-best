import { supabase } from './supabaseService';

export const recoveryService = {
  /**
   * Marca um pagamento como recuperado
   * @param paymentId ID do pagamento a ser marcado
   */
  async markPaymentAsRecovered(paymentId: string): Promise<boolean> {
    try {
      const { data, error } = await supabase
        .rpc('mark_payment_as_recovered', { p_payment_id: paymentId });

      if (error) {
        console.error('Erro ao marcar pagamento como recuperado:', error);
        return false;
      }

      if (data && data.marked_as_recovered) {
        console.log('✅ Pagamento marcado como recuperado:', paymentId);
        return true;
      }

      return false;
    } catch (error) {
      console.error('Erro ao marcar pagamento como recuperado:', error);
      return false;
    }
  },

  /**
   * Verifica se um pagamento foi recuperado através de checkout
   * @param paymentId ID do pagamento
   */
  async isPaymentRecovered(paymentId: string): Promise<boolean> {
    try {
      const { data, error } = await supabase
        .from('payments')
        .select('converted_from_recovery')
        .eq('id', paymentId)
        .single();

      if (error) throw error;
      return data?.converted_from_recovery || false;
    } catch (error) {
      console.error('Erro ao verificar se pagamento foi recuperado:', error);
      return false;
    }
  },

  /**
   * Obtém estatísticas de recuperação
   */
  async getRecoveryStats() {
    try {
      const { data: payments, error } = await supabase
        .from('payments')
        .select('id, amount, status, converted_from_recovery, recovered_at');

      if (error) throw error;

      const recovered = payments?.filter(p => p.converted_from_recovery && p.status === 'paid') || [];
      const totalRecovered = recovered.reduce((sum, p) => sum + Number(p.amount), 0);

      return {
        totalRecovered: recovered.length,
        totalAmount: totalRecovered,
        payments: recovered,
      };
    } catch (error) {
      console.error('Erro ao obter estatísticas de recuperação:', error);
      return {
        totalRecovered: 0,
        totalAmount: 0,
        payments: [],
      };
    }
  },
};

