/*
  # Adicionar payment_bestfy_id ao retorno de get_checkout_by_slug

  1. Problema
    - Função não retorna payment_bestfy_id (bestfy_id do payment)
    - Frontend precisa desse ID para gerar PIX na API Bestfy
    - Erro: "transação undefined"

  2. Solução
    - Adicionar payment_bestfy_id à RETURNS TABLE
    - Buscar p.bestfy_id da tabela payments
    - Retornar no SELECT final

  3. Notas
    - Campo é obrigatório para gerar PIX
    - Já existe na tabela payments
*/

-- Drop da função existente
DROP FUNCTION IF EXISTS get_checkout_by_slug(TEXT);

-- Recria com payment_bestfy_id incluído
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
  original_amount DECIMAL,
  discount_percentage DECIMAL,
  discount_amount DECIMAL,
  final_amount DECIMAL,
  product_name TEXT,
  status TEXT,
  pix_generated_at TIMESTAMPTZ,
  access_count INTEGER,
  payment_bestfy_id TEXT,
  payment_status TEXT
) AS $$
BEGIN
  -- Incrementa o contador de acessos
  UPDATE checkout_links cl
  SET 
    access_count = cl.access_count + 1,
    last_accessed_at = NOW()
  WHERE cl.checkout_slug = slug;

  -- Retorna os dados do checkout com informações do payment
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
    cl.original_amount,
    cl.discount_percentage,
    cl.discount_amount,
    cl.final_amount,
    p.product_name,
    cl.status,
    cl.pix_generated_at,
    cl.access_count,
    p.bestfy_id as payment_bestfy_id,
    p.status as payment_status
  FROM checkout_links cl
  LEFT JOIN payments p ON p.id = cl.payment_id
  WHERE cl.checkout_slug = slug;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
