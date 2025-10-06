import { supabase } from './supabaseService';
import { Payment } from '../types/bestfy';

export interface UserListItem {
  id: string;
  email: string;
  created_at: string;
}

export const adminService = {
  async getAllUsers(): Promise<UserListItem[]> {
    const { data, error } = await supabase
      .from('users_list')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;
    return data || [];
  },

  async getAllPayments(): Promise<Payment[]> {
    const { data, error } = await supabase
      .from('payments')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;
    return data || [];
  },

  async getPaymentsByUser(userId: string): Promise<Payment[]> {
    const { data, error } = await supabase
      .from('payments')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (error) throw error;
    return data || [];
  },
};
