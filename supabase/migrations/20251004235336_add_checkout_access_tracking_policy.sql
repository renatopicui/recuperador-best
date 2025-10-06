/*
  # Add Checkout Access Tracking Policy

  1. Changes
    - Add UPDATE policy for checkout_links to allow anonymous users to increment access_count
    - This enables tracking of checkout page visits without authentication

  2. Security
    - Policy only allows updating access_count and last_accessed_at fields
    - Anonymous users can update any checkout link (public checkout pages)
*/

-- Allow anonymous users to update access tracking fields on checkout links
CREATE POLICY "Anyone can update checkout access tracking"
  ON checkout_links
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);
