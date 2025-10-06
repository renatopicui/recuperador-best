/*
  # Fix Duplicate UNIQUE Constraints

  1. Changes
    - Remove the old composite constraint `payments_bestfy_id_user_id_key`
    - Keep only `payments_bestfy_id_unique` (single column constraint)
  
  2. Security
    - No changes to RLS policies
    - This only affects constraint enforcement
*/

-- Remove the old composite unique constraint if it exists
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'payments_bestfy_id_user_id_key' 
    AND table_name = 'payments'
  ) THEN
    ALTER TABLE payments DROP CONSTRAINT payments_bestfy_id_user_id_key;
  END IF;
END $$;