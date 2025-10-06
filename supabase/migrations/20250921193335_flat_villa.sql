/*
  # Add composite unique constraint for payments table

  1. Changes
    - Add unique constraint on (bestfy_id, user_id) to support proper conflict resolution
    - This allows upsert operations to work correctly with RLS policies
    - Ensures each user can have their own copy of a bestfy_id payment

  2. Security
    - Maintains existing RLS policies
    - Prevents cross-user data conflicts during upsert operations
*/

-- Add composite unique constraint to support onConflict with user_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'payments_bestfy_id_user_id_key'
  ) THEN
    ALTER TABLE payments ADD CONSTRAINT payments_bestfy_id_user_id_key UNIQUE (bestfy_id, user_id);
  END IF;
END $$;