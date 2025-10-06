/*
  # Corrigir get_checkout_by_slug - Resolver ambiguidade de coluna

  1. Problema
    - Coluna checkout_slug é ambígua (conflito entre variável e coluna)
    - Erro: "column reference checkout_slug is ambiguous"

  2. Solução
    - Usar alias da tabela (cl.checkout_slug) para desambiguar
    - Usar cl. em todas as referências de colunas

  3. Notas
    - Mantém funcionalidade idêntica
    - Apenas corrige ambiguidade de nomes
*/

-- Drop da função com erro
DROP FUNCTION IF EXISTS get_checkout_by_slug(TEXT);

-- Recria a função corrigida
CREATE OR REPLACE FUNCTION get_checkout_by_slug(slug_param TEXT)
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
  access_count INTEGER
) AS $$
BEGIN
  -- Incrementa o contador de acessos - usando alias cl para evitar ambiguidade
  UPDATE checkout_links cl
  SET 
    access_count = cl.access_count + 1,
    last_accessed_at = NOW()
  WHERE cl.checkout_slug = slug_param;

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
    cl.access_count
  FROM checkout_links cl
  LEFT JOIN payments p ON p.id = cl.payment_id
  WHERE cl.checkout_slug = slug_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
