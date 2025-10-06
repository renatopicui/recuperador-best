/*
  # Recreate get_checkout_by_slug with Full Customer Data

  1. Changes
    - Drop existing function
    - Create new function with customer_address and customer_phone
    - Returns complete customer data for creating new transactions

  2. Purpose
    - Allow checkout page to create new Bestfy transactions with complete customer info
    - Include address fields (street, city, state, zipcode, etc.)
    - Include document field (CPF/CNPJ)

  3. Security
    - Function uses SECURITY DEFINER for public access
    - Only returns data for non-expired checkout links
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_checkout_by_slug(text);

-- Create new function with complete customer data
CREATE OR REPLACE FUNCTION get_checkout_by_slug(slug text)
RETURNS TABLE (
  checkout_slug text,
  user_id uuid,
  customer_name text,
  customer_email text,
  customer_document text,
  customer_phone text,
  customer_address jsonb,
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
    p.user_id,
    cl.customer_name,
    cl.customer_email,
    p.customer_document,
    p.customer_phone,
    p.customer_address,
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
