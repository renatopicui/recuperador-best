/*
  # Create Admin Users View

  1. Purpose
    - Create a view that allows admin to see all users
    - Use a simpler approach with a materialized table instead of SECURITY DEFINER
    
  2. New Table
    - users_list - Contains user_id, email, created_at
    - Populated via trigger when users are created
    
  3. Security
    - RLS policy allows only admin to read
*/

-- Create table to store user list (accessible via RLS)
CREATE TABLE IF NOT EXISTS users_list (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE users_list ENABLE ROW LEVEL SECURITY;

-- Policy: Only admin can read
CREATE POLICY "Admin can read all users"
  ON users_list
  FOR SELECT
  TO authenticated
  USING (
    (SELECT auth.jwt()->>'email') = 'adm@bestfybr.com.br'
  );

-- Insert existing users into the table
INSERT INTO users_list (id, email, created_at)
SELECT id, email::text, created_at
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- Create trigger function to auto-insert new users
CREATE OR REPLACE FUNCTION sync_user_to_list()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO users_list (id, email, created_at)
  VALUES (NEW.id, NEW.email::text, NEW.created_at)
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      created_at = EXCLUDED.created_at;
  RETURN NEW;
END;
$$;

-- Create trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION sync_user_to_list();
