/*
  # Add Recovery Tracking to Payments Table

  1. New Columns
    - `recovery_source` (text) - Source of the payment:
      - 'organic' - Original transaction from Bestfy
      - 'recovery_checkout' - Payment made through our recovery checkout
      - 'direct' - Direct payment (future use)
    - `recovery_checkout_link_id` (uuid) - Foreign key to checkout_links table (nullable)
      - Links payment to the specific checkout link used for recovery
    - `converted_from_recovery` (boolean) - Flag indicating if this is a recovered sale
      - TRUE when payment from recovery checkout is marked as paid
  
  2. Purpose
    - Track which payments came from recovery efforts
    - Measure conversion rate of recovery checkouts
    - Calculate ROI of recovery system
    - Enable detailed analytics and reporting
  
  3. Default Values
    - recovery_source defaults to 'organic' for existing payments
    - converted_from_recovery defaults to FALSE
  
  4. Indexes
    - Index on recovery_source for fast filtering
    - Index on converted_from_recovery for metrics queries
    - Index on recovery_checkout_link_id for join queries
*/

-- Add recovery tracking columns to payments table
ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS recovery_source text DEFAULT 'organic',
ADD COLUMN IF NOT EXISTS recovery_checkout_link_id uuid REFERENCES checkout_links(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS converted_from_recovery boolean DEFAULT false;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_payments_recovery_source ON payments(recovery_source);
CREATE INDEX IF NOT EXISTS idx_payments_converted_from_recovery ON payments(converted_from_recovery);
CREATE INDEX IF NOT EXISTS idx_payments_recovery_checkout_link_id ON payments(recovery_checkout_link_id);

-- Add comment to explain the columns
COMMENT ON COLUMN payments.recovery_source IS 'Source of payment: organic, recovery_checkout, or direct';
COMMENT ON COLUMN payments.recovery_checkout_link_id IS 'Reference to checkout link used for recovery (if applicable)';
COMMENT ON COLUMN payments.converted_from_recovery IS 'TRUE if payment was recovered through our checkout system';