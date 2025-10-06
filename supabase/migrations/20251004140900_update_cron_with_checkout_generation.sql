/*
  # Update Cron Job to Include Checkout Link Generation

  1. Updates
    - Modifies existing cron job to also generate checkout links
    - Runs both recovery emails AND checkout generation every minute
    
  2. Process Flow (every minute):
    - Step 1: Generate checkout links for payments pending > 3 min
    - Step 2: Send recovery emails for payments pending > 3 min
    
  3. Notes
    - Both functions run in sequence
    - Checkout links are generated BEFORE emails are sent
    - This ensures emails can include the checkout link in future updates
*/

-- Drop existing cron job
SELECT cron.unschedule('send-recovery-emails') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'send-recovery-emails'
);

-- Create new combined cron job
SELECT cron.schedule(
  'recovery-system',
  '* * * * *',  -- Every minute
  $$
    -- Step 1: Generate checkout links for pending payments
    SELECT generate_checkout_links_for_pending_payments();
    
    -- Step 2: Send recovery emails
    SELECT send_pending_recovery_emails();
  $$
);