/*
  # Create Admin Policies

  1. Purpose
    - Allow admin user (adm@bestfybr.com.br) to view all users and payments
    - Create policies for admin to access all data in the system
    - Maintain existing user policies (users still only see their own data)

  2. Admin Policies
    - Admin can view all payments
    - Admin can view all api_keys
    - Admin can view all checkout_links
    - Admin can view all system_settings
    
  3. Security
    - Only users with email = 'adm@bestfybr.com.br' have admin access
    - Regular users maintain their existing RLS policies
*/

-- Admin can view all payments
CREATE POLICY "Admin can view all payments" ON payments
  FOR SELECT
  TO authenticated
  USING (
    (SELECT email FROM auth.users WHERE id = auth.uid()) = 'adm@bestfybr.com.br'
  );

-- Admin can view all api_keys
CREATE POLICY "Admin can view all api_keys" ON api_keys
  FOR SELECT
  TO authenticated
  USING (
    (SELECT email FROM auth.users WHERE id = auth.uid()) = 'adm@bestfybr.com.br'
  );

-- Admin can view all checkout_links
CREATE POLICY "Admin can view all checkout_links" ON checkout_links
  FOR SELECT
  TO authenticated
  USING (
    (SELECT email FROM auth.users WHERE id = auth.uid()) = 'adm@bestfybr.com.br'
  );

-- Admin can view all system_settings
CREATE POLICY "Admin can view all system_settings" ON system_settings
  FOR SELECT
  TO authenticated
  USING (
    (SELECT email FROM auth.users WHERE id = auth.uid()) = 'adm@bestfybr.com.br'
  );
