/*
  # Add user_id to checkout_links table

  1. Changes
    - Add `user_id` column to checkout_links table
    - Reference auth.users table
    - Populate existing records with user_id from related payment
    - Update RLS policies to use user_id directly

  2. Purpose
    - Enable direct user-based queries on checkout_links
    - Improve performance of recovery stats queries
    - Simplify RLS policies
*/

-- Add user_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'checkout_links' AND column_name = 'user_id'
  ) THEN
    ALTER TABLE checkout_links 
    ADD COLUMN user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;
    
    -- Populate user_id from related payment
    UPDATE checkout_links cl
    SET user_id = p.user_id
    FROM payments p
    WHERE cl.payment_id = p.id;
    
    -- Create index for performance
    CREATE INDEX IF NOT EXISTS idx_checkout_links_user_id ON checkout_links(user_id);
    
    -- Update RLS policy to use user_id directly
    DROP POLICY IF EXISTS "Users can read own checkout links" ON checkout_links;
    CREATE POLICY "Users can read own checkout links"
      ON checkout_links FOR SELECT
      TO authenticated
      USING (user_id = auth.uid());
  END IF;
END $$;