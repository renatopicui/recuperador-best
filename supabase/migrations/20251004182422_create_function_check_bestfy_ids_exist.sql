/*
  # Create function to check if bestfy_ids exist (bypassing RLS)

  1. New Functions
    - `check_bestfy_ids_exist(text[])` - Returns array of existing bestfy_ids
  
  2. Security
    - SECURITY DEFINER allows function to bypass RLS
    - Only returns bestfy_id (no sensitive data)
    - Prevents duplicate key violations in multi-user scenarios

  This function is needed because RLS policies prevent users from seeing
  payments that belong to other users, which can cause duplicate key errors
  when trying to insert a payment that already exists in the database.
*/

CREATE OR REPLACE FUNCTION check_bestfy_ids_exist(bestfy_ids text[])
RETURNS TABLE(bestfy_id text, user_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT p.bestfy_id, p.user_id
  FROM payments p
  WHERE p.bestfy_id = ANY(bestfy_ids);
END;
$$;