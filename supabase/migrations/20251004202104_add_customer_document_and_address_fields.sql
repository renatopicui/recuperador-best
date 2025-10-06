/*
  # Add Customer Document and Address Fields to Payments Table

  1. New Columns
    - `customer_document` (text) - CPF or CNPJ of the customer
    - `customer_address` (jsonb) - Complete address information including:
      - street
      - streetNumber
      - complementary
      - neighborhood
      - city
      - state
      - zipcode
      - country

  2. Purpose
    - Store complete customer data from Bestfy transactions
    - Allow creating new transactions with the same customer information
    - Enable recovery emails with all customer details

  3. Security
    - RLS remains active on payments table
    - All fields are nullable for backward compatibility
*/

-- Add customer document field
ALTER TABLE payments ADD COLUMN IF NOT EXISTS customer_document text;

-- Add customer address as JSONB for flexibility
ALTER TABLE payments ADD COLUMN IF NOT EXISTS customer_address jsonb;

-- Add index for searching by document
CREATE INDEX IF NOT EXISTS idx_payments_customer_document ON payments(customer_document);

-- Add comments for documentation
COMMENT ON COLUMN payments.customer_document IS 'CPF or CNPJ of the customer';
COMMENT ON COLUMN payments.customer_address IS 'Complete address information in JSON format';
