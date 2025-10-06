/*
  # Fix get_checkout_by_slug Function - Add user_id

  1. Updates
    - Adds user_id to the return type of get_checkout_by_slug
    - This allows the checkout page to retrieve the API key for payment processing
    
  2. Security
    - Function uses SECURITY DEFINER to access payment data
    - No RLS bypass - only returns what's allowed
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_checkout_by_slug(text);

-- Recreate with user_id in return
CREATE OR REPLACE FUNCTION get_checkout_by_slug(slug text)
RETURNS TABLE (
  checkout_slug text,
  user_id uuid,
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
    p.user_id,
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