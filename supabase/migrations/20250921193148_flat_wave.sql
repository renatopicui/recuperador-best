/*
  # Fix RLS policies for payments table

  1. Security Updates
    - Drop existing restrictive policies
    - Create proper INSERT policy for authenticated users
    - Create proper UPDATE policy for authenticated users
    - Ensure SELECT policy allows users to read their own data

  2. Policy Details
    - INSERT: Users can insert payments with their own user_id
    - UPDATE: Users can update payments where user_id matches their auth.uid()
    - SELECT: Users can view payments where user_id matches their auth.uid()

  This fixes the "new row violates row-level security policy" error by ensuring
  authenticated users can properly insert and update their own payment records.
*/

-- Drop existing policies that might be too restrictive
DROP POLICY IF EXISTS "Users can insert their own payments" ON payments;
DROP POLICY IF EXISTS "Users can update their own payments" ON payments;
DROP POLICY IF EXISTS "Users can view their own payments" ON payments;
DROP POLICY IF EXISTS "Allow webhook to insert payments" ON payments;
DROP POLICY IF EXISTS "Allow webhook to update payments" ON payments;

-- Create proper INSERT policy for authenticated users
CREATE POLICY "Users can insert their own payments"
  ON payments
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Create proper UPDATE policy for authenticated users  
CREATE POLICY "Users can update their own payments"
  ON payments
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create proper SELECT policy for authenticated users
CREATE POLICY "Users can view their own payments"
  ON payments
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Allow webhook service to insert/update payments (for webhook endpoint)
CREATE POLICY "Allow webhook to insert payments"
  ON payments
  FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Allow webhook to update payments"
  ON payments
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);