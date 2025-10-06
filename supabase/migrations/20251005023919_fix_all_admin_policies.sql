/*
  # Fix All Admin Policies

  1. Problem
    - Multiple tables have policies that join auth.users
    - This causes "permission denied for table users" error
    
  2. Solution
    - Fix policies for: api_keys, checkout_links, system_settings
    - Use direct auth.uid() comparison instead of email lookup
    - Admin user ID: 4f106ef5-e0cd-40ae-bfed-32dc5661540d
*/

-- Fix api_keys policy
DROP POLICY IF EXISTS "Admin can view all api_keys" ON api_keys;
CREATE POLICY "Admin can view all api_keys"
  ON api_keys
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = '4f106ef5-e0cd-40ae-bfed-32dc5661540d'::uuid
  );

-- Fix checkout_links policy
DROP POLICY IF EXISTS "Admin can view all checkout_links" ON checkout_links;
CREATE POLICY "Admin can view all checkout_links"
  ON checkout_links
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = '4f106ef5-e0cd-40ae-bfed-32dc5661540d'::uuid
  );

-- Fix system_settings policy
DROP POLICY IF EXISTS "Admin can view all system_settings" ON system_settings;
CREATE POLICY "Admin can view all system_settings"
  ON system_settings
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = '4f106ef5-e0cd-40ae-bfed-32dc5661540d'::uuid
  );
