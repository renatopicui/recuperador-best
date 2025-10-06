/*
  # Fix get_checkout_by_slug Function
  
  1. Problem
    - Function references columns that don't exist: customer_phone, customer_address
    - This causes checkout pages to fail with error
    
  2. Solution
    - Recreate function without non-existent columns
    - Return only columns that actually exist in checkout_links table
*/

-- Drop and recreate the function with correct columns
DROP FUNCTION IF EXISTS get_checkout_by_slug(TEXT);

CREATE FUNCTION get_checkout_by_slug(slug TEXT)
RETURNS TABLE (
    checkout_slug TEXT,
    user_id UUID,
    customer_name TEXT,
    customer_email TEXT,
    customer_document TEXT,
    product_name TEXT,
    amount NUMERIC,
    items JSONB,
    metadata JSONB,
    expires_at TIMESTAMPTZ,
    payment_status TEXT,
    payment_bestfy_id TEXT,
    pix_qrcode TEXT,
    pix_expires_at TIMESTAMPTZ,
    pix_generated_at TIMESTAMPTZ,
    access_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cl.checkout_slug,
        cl.user_id,
        cl.customer_name,
        cl.customer_email,
        cl.customer_document,
        cl.product_name,
        cl.amount,
        cl.items,
        cl.metadata,
        cl.expires_at,
        cl.payment_status,
        cl.payment_bestfy_id,
        cl.pix_qrcode,
        cl.pix_expires_at,
        cl.pix_generated_at,
        cl.access_count
    FROM checkout_links cl
    WHERE cl.checkout_slug = slug
    AND cl.expires_at > now()
    LIMIT 1;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_checkout_by_slug(TEXT) TO anon, authenticated;