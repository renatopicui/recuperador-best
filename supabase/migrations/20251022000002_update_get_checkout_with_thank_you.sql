/*
  # Atualizar get_checkout_by_slug para incluir thank_you_slug
  
  Adiciona o campo thank_you_slug no retorno da função get_checkout_by_slug
*/

CREATE OR REPLACE FUNCTION get_checkout_by_slug(slug text)
RETURNS TABLE (
  checkout_slug text,
  thank_you_slug text,
  customer_name text,
  customer_email text,
  customer_document text,
  product_name text,
  amount numeric,
  original_amount numeric,
  discount_percentage integer,
  discount_amount numeric,
  final_amount numeric,
  items jsonb,
  metadata jsonb,
  expires_at timestamptz,
  payment_status text,
  payment_bestfy_id text,
  payment_id uuid,
  pix_qrcode text,
  pix_expires_at timestamptz,
  pix_generated_at timestamptz,
  customer_address jsonb,
  id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM increment_checkout_access(slug);
  
  RETURN QUERY
  SELECT 
    cl.checkout_slug,
    cl.thank_you_slug,
    cl.customer_name,
    cl.customer_email,
    cl.customer_document,
    cl.product_name,
    cl.amount,
    cl.original_amount,
    cl.discount_percentage,
    cl.discount_amount,
    cl.final_amount,
    cl.items,
    cl.metadata,
    cl.expires_at,
    p.status as payment_status,
    p.bestfy_id as payment_bestfy_id,
    p.id as payment_id,
    p.pix_data->>'qrcode' as pix_qrcode,
    (p.pix_data->>'expires_at')::timestamptz as pix_expires_at,
    (p.pix_data->>'generated_at')::timestamptz as pix_generated_at,
    cl.customer_address,
    cl.id
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.checkout_slug = slug
    AND cl.expires_at > NOW();
END;
$$;

COMMENT ON FUNCTION get_checkout_by_slug IS 'Retorna dados do checkout incluindo thank_you_slug para redirecionamento';

