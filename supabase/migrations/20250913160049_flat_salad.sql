/*
  # Fix RLS policies for payments table

  1. Security Changes
    - Drop existing restrictive policies
    - Add permissive policies for authenticated and anon users
    - Allow INSERT, SELECT, and UPDATE operations for payment data

  2. Notes
    - This allows the application to save payment data from the Bestfy API
    - Policies are set to allow operations for both authenticated and anon users
    - For production, consider more restrictive policies based on your security requirements
*/

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can insert payments" ON payments;
DROP POLICY IF EXISTS "Users can read all payments" ON payments;
DROP POLICY IF EXISTS "Users can update payments" ON payments;

-- Create new permissive policies for anon and authenticated users
CREATE POLICY "Allow insert payments for anon users"
  ON payments
  FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Allow insert payments for authenticated users"
  ON payments
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Allow select payments for anon users"
  ON payments
  FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Allow select payments for authenticated users"
  ON payments
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow update payments for anon users"
  ON payments
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow update payments for authenticated users"
  ON payments
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);