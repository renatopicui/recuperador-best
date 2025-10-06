import { supabase } from './supabaseService';
import { Payment } from '../types/bestfy';

export const bestfyService = {
  async getPayments(): Promise<Payment[]> {
    const { data, error } = await supabase
      .from('payments')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;
    return data || [];
  },

  async getPaymentById(id: string): Promise<Payment | null> {
    const { data, error } = await supabase
      .from('payments')
      .select('*')
      .eq('id', id)
      .maybeSingle();

    if (error) throw error;
    return data;
  },

  async createPayment(paymentData: any): Promise<Payment> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('User not authenticated');

    const { data: apiKeyData } = await supabase
      .from('api_keys')
      .select('encrypted_key')
      .eq('user_id', user.id)
      .eq('is_active', true)
      .maybeSingle();

    if (!apiKeyData) throw new Error('API Key não configurada');

    const bestfyResponse = await fetch('https://api.bestfy.com.br/v1/charges', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKeyData.encrypted_key}`,
      },
      body: JSON.stringify({
        amount: paymentData.amount,
        customer: {
          name: paymentData.customerName,
          email: paymentData.customerEmail,
          document: paymentData.customerDocument,
          phone: paymentData.customerPhone,
        },
        items: [{
          name: paymentData.productName,
          quantity: 1,
          amount: paymentData.amount,
        }],
        payment_method: 'pix',
      }),
    });

    if (!bestfyResponse.ok) {
      throw new Error('Erro ao criar cobrança na Bestfy');
    }

    const bestfyData = await bestfyResponse.json();

    const { data, error } = await supabase
      .from('payments')
      .insert({
        user_id: user.id,
        bestfy_id: bestfyData.id,
        customer_name: paymentData.customerName,
        customer_email: paymentData.customerEmail,
        customer_phone: paymentData.customerPhone,
        customer_document: paymentData.customerDocument,
        customer_address: paymentData.customerAddress,
        product_name: paymentData.productName,
        amount: paymentData.amount,
        status: bestfyData.status || 'waiting_payment',
        secure_url: bestfyData.secure_url,
        payment_method: 'pix',
      })
      .select()
      .single();

    if (error) throw error;
    return data;
  },

  async syncPayments(): Promise<{ updated: number; unchanged: number }> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('User not authenticated');

    const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    const { data: { session } } = await supabase.auth.getSession();

    const response = await fetch(`${supabaseUrl}/functions/v1/bestfy-sync`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${session?.access_token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      throw new Error('Erro ao sincronizar pagamentos');
    }

    return await response.json();
  },
};
