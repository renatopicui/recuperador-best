/*
  # Remove single bestfy_id unique constraint

  This migration removes the single-column unique constraint on bestfy_id
  to allow the same bestfy_id to exist for different users, while keeping
  the composite unique constraint on (bestfy_id, user_id).

  1. Changes
    - Drop the single bestfy_id unique constraint
    - Keep the composite (bestfy_id, user_id) unique constraint
    - This allows webhooks and multi-user scenarios to work properly
*/

-- Drop the single bestfy_id unique constraint
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_bestfy_id_key;

-- Ensure the composite unique constraint exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'payments_bestfy_id_user_id_key'
  ) THEN
    ALTER TABLE payments ADD CONSTRAINT payments_bestfy_id_user_id_key UNIQUE (bestfy_id, user_id);
  END IF;
END $$;