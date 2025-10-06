/*
  # Fix Admin Get Users Function

  1. Problem
    - Function was expecting 'text' type for email but auth.users.email is varchar(255)
    - This caused a type mismatch error
    
  2. Solution
    - Drop and recreate function with correct type casting
    - Cast email to text explicitly
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_all_users_for_admin();

-- Recreate function with proper type casting
CREATE OR REPLACE FUNCTION get_all_users_for_admin()
RETURNS TABLE (
  user_id uuid,
  email text,
  created_at timestamptz
) 
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  -- Check if caller is admin
  IF (SELECT auth.jwt()->>'email') != 'adm@bestfybr.com.br' THEN
    RAISE EXCEPTION 'Access denied. Admin only.';
  END IF;

  -- Return all users with proper type casting
  RETURN QUERY
  SELECT 
    id as user_id,
    auth.users.email::text as email,
    auth.users.created_at as created_at
  FROM auth.users
  ORDER BY auth.users.created_at DESC;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_all_users_for_admin() TO authenticated;
