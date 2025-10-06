/*
  # Corrigir get_checkout_by_slug para usar payment_bestfy_id

  1. Problema
    - Função usa JOIN com payment_id (ID interno UUID)
    - Quando PIX é gerado, novo pagamento é criado na Bestfy
    - payment_bestfy_id é atualizado mas payment_id não
    - Resultado: retorna dados do pagamento ANTIGO

  2. Solução
    - Fazer JOIN usando payment_bestfy_id
    - Usar cl.payment_bestfy_id e cl.payment_status diretamente
    - Buscar payment apenas para pegar product_name

  3. Impacto
    - Status será atualizado corretamente após pagamento
    - Polling vai detectar mudança de status
    - Redirecionamento para página de obrigado funcionará
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
    cl.payment_bestfy_id,
    cl.payment_status
  FROM checkout_links cl
  LEFT JOIN payments p ON p.bestfy_id = cl.payment_bestfy_id
  WHERE cl.checkout_slug = slug;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
