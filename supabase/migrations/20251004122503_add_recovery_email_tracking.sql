/*
  # Add Recovery Email Tracking

  1. Changes
    - Add `recovery_email_sent_at` column to track when recovery emails were sent
    - This prevents sending duplicate recovery emails to the same payment
  
  2. Security
    - No changes to RLS policies
*/

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'payments' 
    AND column_name = 'recovery_email_sent_at'
  ) THEN
    ALTER TABLE payments 
    ADD COLUMN recovery_email_sent_at timestamptz DEFAULT NULL;
    
    CREATE INDEX IF NOT EXISTS idx_payments_recovery_email 
    ON payments(status, created_at, recovery_email_sent_at) 
    WHERE status = 'waiting_payment' AND recovery_email_sent_at IS NULL;
  END IF;
END $$;