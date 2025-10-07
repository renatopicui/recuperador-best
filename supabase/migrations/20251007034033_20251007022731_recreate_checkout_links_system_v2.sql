/*
  # Recreate Checkout Links System (v2)

  1. Tables
    - `checkout_links` - Stores custom checkout links for recovery emails

  2. Functions
    - Drops old functions first, then recreates

  3. Security
    - Enable RLS on checkout_links
*/

-- Drop old functions first
DROP FUNCTION IF EXISTS get_checkout_by_slug(text);
DROP FUNCTION IF EXISTS generate_checkout_links_for_pending_payments();
DROP FUNCTION IF EXISTS increment_checkout_access(text);
DROP FUNCTION IF EXISTS generate_checkout_slug();

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
  items jsonb,
  metadata jsonb,
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT (now() + INTERVAL '24 hours'),
  access_count integer DEFAULT 0,
  last_accessed_at timestamptz
);

-- Enable RLS
ALTER TABLE checkout_links ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read their own checkout links
DROP POLICY IF EXISTS "Users can read own checkout links" ON checkout_links;
CREATE POLICY "Users can read own checkout links"
  ON checkout_links FOR SELECT
  TO authenticated
  USING (
    payment_id IN (
      SELECT id FROM payments WHERE user_id = auth.uid()
    )
  );

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_checkout_links_slug ON checkout_links(checkout_slug);
CREATE INDEX IF NOT EXISTS idx_checkout_links_payment_id ON checkout_links(payment_id);
CREATE INDEX IF NOT EXISTS idx_checkout_links_expires_at ON checkout_links(expires_at);

-- Function to generate unique checkout slug
CREATE OR REPLACE FUNCTION generate_checkout_slug()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  chars text := 'abcdefghijklmnopqrstuvwxyz0123456789';
  result text := '';
  i integer;
  slug_exists boolean := true;
BEGIN
  WHILE slug_exists LOOP
    result := '';
    FOR i IN 1..8 LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    
    SELECT EXISTS(SELECT 1 FROM checkout_links WHERE checkout_slug = result) INTO slug_exists;
  END LOOP;
  
  RETURN result;
END;
$$;

-- Function to increment checkout access counter
CREATE OR REPLACE FUNCTION increment_checkout_access(slug text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE checkout_links
  SET 
    access_count = access_count + 1,
    last_accessed_at = NOW()
  WHERE checkout_slug = slug;
END;
$$;

-- Function to generate checkout links for pending payments
CREATE OR REPLACE FUNCTION generate_checkout_links_for_pending_payments()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_payment RECORD;
  v_new_slug text;
  v_created_count integer := 0;
  v_errors integer := 0;
  v_error_message text;
BEGIN
  FOR v_payment IN
    SELECT 
      p.id,
      p.bestfy_id,
      p.customer_name,
      p.customer_email,
      p.customer_phone as customer_document,
      p.product_name,
      p.amount
    FROM payments p
    WHERE p.status = 'waiting_payment'
      AND p.payment_method = 'pix'
      AND p.created_at < (NOW() - INTERVAL '3 minutes')
      AND NOT EXISTS (
        SELECT 1 
        FROM checkout_links cl 
        WHERE cl.payment_id = p.id
      )
  LOOP
    BEGIN
      v_new_slug := generate_checkout_slug();
      
      INSERT INTO checkout_links (
        payment_id,
        checkout_slug,
        customer_name,
        customer_email,
        customer_document,
        product_name,
        amount
      ) VALUES (
        v_payment.id,
        v_new_slug,
        v_payment.customer_name,
        v_payment.customer_email,
        v_payment.customer_document,
        v_payment.product_name,
        v_payment.amount
      );
      
      v_created_count := v_created_count + 1;
      RAISE NOTICE '✅ Checkout link created: % for payment %', v_new_slug, v_payment.bestfy_id;
      
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      v_error_message := SQLERRM;
      RAISE WARNING '❌ Error creating checkout for payment %: %', v_payment.bestfy_id, v_error_message;
    END;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true,
    'checkout_links_created', v_created_count,
    'errors', v_errors,
    'timestamp', NOW()
  );
END;
$$;

-- Function to get checkout link details by slug
CREATE OR REPLACE FUNCTION get_checkout_by_slug(slug text)
RETURNS TABLE (
  checkout_slug text,
  customer_name text,
  customer_email text,
  customer_document text,
  product_name text,
  amount numeric,
  items jsonb,
  metadata jsonb,
  expires_at timestamptz,
  payment_status text,
  payment_bestfy_id text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM increment_checkout_access(slug);
  
  RETURN QUERY
  SELECT 
    cl.checkout_slug,
    cl.customer_name,
    cl.customer_email,
    cl.customer_document,
    cl.product_name,
    cl.amount,
    cl.items,
    cl.metadata,
    cl.expires_at,
    p.status as payment_status,
    p.bestfy_id as payment_bestfy_id
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.checkout_slug = slug
    AND cl.expires_at > NOW();
END;
$$;