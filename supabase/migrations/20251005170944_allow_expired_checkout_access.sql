/*
  # Permitir acesso a checkouts expirados
  
  1. Alterações
    - Remover verificação de expiração da função get_checkout_by_slug
    - Permitir que usuários acessem checkouts expirados para gerar novo PIX
*/

DROP FUNCTION IF EXISTS get_checkout_by_slug(TEXT);

CREATE OR REPLACE FUNCTION get_checkout_by_slug(slug TEXT)
RETURNS TABLE(
  id UUID,
  checkout_slug TEXT,
  payment_id UUID,
  user_id UUID,
  customer_email TEXT,
  customer_name TEXT,
  customer_document TEXT,
  customer_address JSONB,
  amount DECIMAL,
  original_amount DECIMAL,
  discount_percentage DECIMAL,
  discount_amount DECIMAL,
  final_amount DECIMAL,
  product_name TEXT,
  status TEXT,
  pix_qrcode TEXT,
  pix_expires_at TIMESTAMPTZ,
  pix_generated_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  access_count INTEGER,
  payment_bestfy_id TEXT,
  payment_status TEXT
) AS $$
BEGIN
  -- Incrementar contador de acesso
  UPDATE checkout_links cl
  SET 
    access_count = cl.access_count + 1,
    last_accessed_at = NOW()
  WHERE cl.checkout_slug = slug;

  RETURN QUERY
  SELECT 
    cl.id,
    cl.checkout_slug,
    cl.payment_id,
    cl.user_id,
    cl.customer_email,
    cl.customer_name,
    cl.customer_document,
    cl.customer_address,
    cl.amount,
    cl.original_amount,
    cl.discount_percentage,
    cl.discount_amount,
    cl.final_amount,
    cl.product_name,
    cl.status,
    cl.pix_qrcode,
    cl.pix_expires_at,
    cl.pix_generated_at,
    cl.expires_at,
    cl.access_count,
    cl.payment_bestfy_id,
    cl.payment_status
  FROM checkout_links cl
  WHERE cl.checkout_slug = slug;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;