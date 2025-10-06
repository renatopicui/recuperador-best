import { supabase } from './supabaseService';
import { CheckoutLink } from '../types/bestfy';

export const checkoutService = {
  async generateCheckoutLink(paymentId: string): Promise<CheckoutLink> {
    const { data, error } = await supabase
      .rpc('generate_checkout_link', { payment_id: paymentId });

    if (error) throw error;
    return data;
  },

  async getCheckoutBySlug(slug: string): Promise<CheckoutLink | null> {
    const { data, error } = await supabase
      .rpc('get_checkout_by_slug', { slug });

    if (error) throw error;

    // A função RPC retorna um array, pegar o primeiro elemento
    if (Array.isArray(data) && data.length > 0) {
      return data[0];
    }

    return null;
  },

  async updateCheckoutAccess(checkoutId: string) {
    const { error } = await supabase
      .from('checkout_links')
      .update({
        access_count: supabase.raw('access_count + 1'),
        last_accessed_at: new Date().toISOString(),
      })
      .eq('id', checkoutId);

    if (error) throw error;
  },
};
