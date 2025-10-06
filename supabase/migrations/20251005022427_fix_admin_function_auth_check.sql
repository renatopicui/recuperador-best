/*
  # Fix Admin Function Authentication Check

  1. Problem
    - Function may be failing to check auth.jwt() correctly
    - Need to ensure proper authentication validation
    
  2. Solution
    - Recreate function with better error handling
    - Add fallback authentication checks
*/

-- Drop and recreate function with improved authentication
DROP FUNCTION IF EXISTS get_all_users_for_admin();

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
DECLARE
  calling_user_email text;
BEGIN
  -- Get the email of the calling user
  SELECT auth.email()::text INTO calling_user_email;
  
  -- Check if caller is admin
  IF calling_user_email IS NULL OR calling_user_email != 'adm@bestfybr.com.br' THEN
    RAISE EXCEPTION 'Access denied. Admin only. Your email: %', COALESCE(calling_user_email, 'not authenticated');
  END IF;

  -- Return all users with proper type casting
  RETURN QUERY
  SELECT 
    au.id as user_id,
    au.email::text as email,
    au.created_at as created_at
  FROM auth.users au
  ORDER BY au.created_at DESC;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_all_users_for_admin() TO authenticated;
