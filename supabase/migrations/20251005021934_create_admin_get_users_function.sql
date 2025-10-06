/*
  # Create Admin Function to Get Users

  1. Purpose
    - Create a function that returns user emails for admin
    - Admin can call this function to get list of all users with their emails
    
  2. Function
    - get_all_users_for_admin() - Returns user_id and email for all users
    
  3. Security
    - Only callable by admin user (adm@bestfybr.com.br)
    - Uses SECURITY DEFINER to access auth.users table
*/

-- Create function to get all users (only for admin)
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

  -- Return all users
  RETURN QUERY
  SELECT 
    id as user_id,
    auth.users.email as email,
    auth.users.created_at as created_at
  FROM auth.users
  ORDER BY auth.users.created_at DESC;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_all_users_for_admin() TO authenticated;
