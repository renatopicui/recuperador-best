/*
  # Fix Admin Payments Policy

  1. Problem
    - Policy "Admin can view all payments" tries to join auth.users
    - This causes "permission denied for table users" error
    
  2. Solution
    - Drop the problematic policy
    - Create new policy using direct auth.uid() comparison
    - Admin user ID: 4f106ef5-e0cd-40ae-bfed-32dc5661540d
*/

-- Drop old policy
DROP POLICY IF EXISTS "Admin can view all payments" ON payments;

-- Create new policy for admin using UUID directly
CREATE POLICY "Admin can view all payments"
  ON payments
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = '4f106ef5-e0cd-40ae-bfed-32dc5661540d'::uuid
  );
