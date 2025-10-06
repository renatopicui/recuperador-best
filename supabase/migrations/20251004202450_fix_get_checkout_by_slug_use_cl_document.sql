/*
  # Fix get_checkout_by_slug to Use checkout_links.customer_document

  1. Problem
    - payments.customer_document is NULL for older transactions
    - checkout_links.customer_document has the data
    - Need to use checkout_links.customer_document as primary source

  2. Solution
    - Use COALESCE to try checkout_links.customer_document first
    - Fall back to payments.customer_document if available
    - This ensures we always have customer document when available

  3. Security
    - Function remains SECURITY DEFINER for public access
*/

DROP FUNCTION IF EXISTS get_checkout_by_slug(text);

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
    COALESCE(cl.customer_document, p.customer_document, '') as customer_document,
    COALESCE(p.customer_phone, '') as customer_phone,
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
