/*
  # Fix get_checkout_by_slug to Include Payment Data
  
  1. Problem
    - When payment_bestfy_id is NULL in checkout_links, we need to get it from the associated payment
    - When customer_document is NULL in checkout_links, we need to get it from the payment
    - This causes checkout to fail because it can't fetch the original transaction
    
  2. Solution
    - Join with payments table to get missing data
    - Return payment.bestfy_id as fallback when checkout.payment_bestfy_id is NULL
    - Return payment.customer_document as fallback when checkout.customer_document is NULL
*/

-- Drop and recreate the function with payment data join
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
        COALESCE(cl.customer_document, p.customer_document) as customer_document,
        cl.product_name,
        cl.amount,
        cl.items,
        cl.metadata,
        cl.expires_at,
        COALESCE(cl.payment_status, p.status) as payment_status,
        COALESCE(cl.payment_bestfy_id, p.bestfy_id) as payment_bestfy_id,
        cl.pix_qrcode,
        cl.pix_expires_at,
        cl.pix_generated_at,
        cl.access_count
    FROM checkout_links cl
    LEFT JOIN payments p ON cl.payment_id = p.id
    WHERE cl.checkout_slug = slug
    AND cl.expires_at > now()
    LIMIT 1;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_checkout_by_slug(TEXT) TO anon, authenticated;
