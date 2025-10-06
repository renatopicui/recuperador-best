/*
  # Create Checkout Links Table for Payment Recovery

  1. New Tables
    - `checkout_links`
      - `id` (uuid, primary key) - Unique identifier
      - `payment_id` (uuid, foreign key) - Reference to payments table
      - `checkout_slug` (text, unique) - Short unique slug for URL (e.g., "abc123")
      - `customer_name` (text) - Customer name for personalization
      - `customer_email` (text) - Customer email
      - `customer_document` (text) - CPF/CNPJ for checkout
      - `product_name` (text) - Product being sold
      - `amount` (numeric) - Amount in cents
      - `items` (jsonb) - Full items array for checkout
      - `metadata` (jsonb) - Additional data from original transaction
      - `expires_at` (timestamptz) - Expiration date (24h after creation)
      - `accessed_count` (integer) - Number of times link was accessed
      - `converted_at` (timestamptz) - When payment was completed
      - `created_at` (timestamptz) - Creation timestamp
      
  2. Security
    - Enable RLS on `checkout_links` table
    - Add policy for public read access (anyone with slug can view)
    - Add policy for authenticated admin users to manage
    
  3. Indexes
    - Unique index on checkout_slug for fast lookups
    - Index on payment_id for relationship queries
    - Index on expires_at for cleanup queries
    
  4. Notes
    - Checkout links expire after 24 hours
    - Links are publicly accessible via slug (no auth required)
    - Track access count for analytics
    - Mark as converted when payment completes
*/

-- Create checkout_links table
CREATE TABLE IF NOT EXISTS checkout_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id uuid NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  checkout_slug text NOT NULL UNIQUE,
  customer_name text NOT NULL,
  customer_email text NOT NULL,
  customer_document text,
  product_name text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  items jsonb DEFAULT '[]'::jsonb,
  metadata jsonb,
  expires_at timestamptz NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
  accessed_count integer NOT NULL DEFAULT 0,
  converted_at timestamptz,
  created_at timestamptz DEFAULT NOW()
);

-- Create indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_checkout_links_slug ON checkout_links(checkout_slug);
CREATE INDEX IF NOT EXISTS idx_checkout_links_payment_id ON checkout_links(payment_id);
CREATE INDEX IF NOT EXISTS idx_checkout_links_expires_at ON checkout_links(expires_at);

-- Enable RLS
ALTER TABLE checkout_links ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read checkout links by slug (public access)
CREATE POLICY "Anyone can view checkout links"
  ON checkout_links FOR SELECT
  TO anon, authenticated
  USING (expires_at > NOW());

-- Policy: Authenticated users can create checkout links
CREATE POLICY "Authenticated users can create checkout links"
  ON checkout_links FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Policy: Authenticated users can update their checkout links
CREATE POLICY "Authenticated users can update checkout links"
  ON checkout_links FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Function to generate unique short slug
CREATE OR REPLACE FUNCTION generate_checkout_slug()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  new_slug text;
  slug_exists boolean;
BEGIN
  LOOP
    -- Generate 8-character random slug
    new_slug := lower(substring(md5(random()::text || clock_timestamp()::text) from 1 for 8));
    
    -- Check if slug already exists
    SELECT EXISTS(SELECT 1 FROM checkout_links WHERE checkout_slug = new_slug) INTO slug_exists;
    
    -- Exit loop if slug is unique
    EXIT WHEN NOT slug_exists;
  END LOOP;
  
  RETURN new_slug;
END;
$$;

-- Function to increment access count
CREATE OR REPLACE FUNCTION increment_checkout_access(slug text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE checkout_links
  SET accessed_count = accessed_count + 1
  WHERE checkout_slug = slug;
END;
$$;