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
      .rpc('get_checkout_by_slug', { p_slug: slug });

    if (error) throw error;

    // A função agora retorna jsonb diretamente
    if (data) {
      return data as CheckoutLink;
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
