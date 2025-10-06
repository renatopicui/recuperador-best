/*
  # Make user_id NOT NULL and add default value

  1. Changes
    - Set user_id to NOT NULL
    - Add default value auth.uid() for new inserts
  
  2. Security
    - Ensures all payments have a valid user_id
    - Fixes RLS policy violations
    - Prevents orphan payments

  Note: All existing NULL user_id records have been updated before this migration.
*/

-- Make user_id NOT NULL with default value
ALTER TABLE payments 
  ALTER COLUMN user_id SET NOT NULL;

-- Set default value for new inserts
ALTER TABLE payments 
  ALTER COLUMN user_id SET DEFAULT auth.uid();