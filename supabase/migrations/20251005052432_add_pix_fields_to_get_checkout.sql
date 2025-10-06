/*
  # Adicionar campos PIX ao retorno de get_checkout_by_slug

  1. Campos Adicionados
    - pix_qrcode: código PIX gerado
    - pix_expires_at: data de expiração do PIX
    - amount: valor original do checkout_link

  2. Funcionalidade
    - Permite restaurar Step 2 se PIX já foi gerado
    - Permite verificar se pagamento já foi pago
    - Mantém estado do checkout ao recarregar página

  3. Notas
    - Essencial para UX - usuário pode recarregar página
    - Campos já existem na tabela checkout_links
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
  access_count INTEGER,
  payment_bestfy_id TEXT,
  payment_status TEXT
) AS $$
BEGIN
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
    p.product_name,
    cl.status,
    cl.pix_qrcode,
    cl.pix_expires_at,
    cl.pix_generated_at,
    cl.access_count,
    p.bestfy_id as payment_bestfy_id,
    p.status as payment_status
  FROM checkout_links cl
  LEFT JOIN payments p ON p.id = cl.payment_id
  WHERE cl.checkout_slug = slug;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
