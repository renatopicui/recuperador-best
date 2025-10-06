export interface Payment {
  id: string;
  user_id?: string;
  bestfy_id: string;
  customer_name: string;
  customer_email: string;
  customer_phone?: string;
  customer_document?: string;
  customer_address?: any;
  product_name: string;
  amount: number;
  currency: string;
  status: string;
  payment_method?: string;
  secure_url?: string;
  created_at: string;
  updated_at: string;
  recovery_email_sent_at?: string;
  recovery_source?: string;
  recovery_checkout_link_id?: string;
  converted_from_recovery?: boolean;
}

export interface CheckoutLink {
  id: string;
  user_id?: string;
  payment_id: string;
  checkout_slug: string;
  customer_name: string;
  customer_email: string;
  customer_document?: string;
  customer_address?: any;
  product_name: string;
  amount: number;
  original_amount?: number;
  discount_percentage?: number;
  discount_amount?: number;
  final_amount?: number;
  payment_bestfy_id?: string;
  payment_status: string;
  pix_qrcode?: string;
  pix_expires_at?: string;
  pix_generated_at?: string;
  status: string;
  expires_at: string;
  created_at: string;
  access_count: number;
  last_accessed_at?: string;
  last_status_check?: string;
  items?: any;
  metadata?: any;
}

export interface ApiKey {
  id: string;
  user_id: string;
  key_name: string;
  encrypted_key: string;
  service: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface EmailSettings {
  id: string;
  user_id: string;
  postmark_token: string;
  from_email: string;
  from_name: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}
