/*
  # Temporary Policy - Allow All Authenticated Users

  1. Purpose
    - TEMPORARY: Allow all authenticated users to read users_list
    - This is for debugging - we will restrict it later
    
  2. Changes
    - Drop existing restrictive policy
    - Create permissive policy for ALL authenticated users
*/

-- Drop existing policy
DROP POLICY IF EXISTS "Admin can read all users" ON users_list;

-- Create temporary permissive policy
CREATE POLICY "Authenticated users can read users_list"
  ON users_list
  FOR SELECT
  TO authenticated
  USING (true);
