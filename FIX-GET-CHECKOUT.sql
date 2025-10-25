-- Script para corrigir apenas a função get_checkout_by_slug
-- Execute este script SOZINHO no SQL Editor

-- Dropar todas as versões da função
DROP FUNCTION IF EXISTS get_checkout_by_slug(text);

-- Recriar de forma simples e compatível
CREATE OR REPLACE FUNCTION get_checkout_by_slug(p_slug text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Incrementar contador de acesso
  UPDATE checkout_links
  SET 
    access_count = COALESCE(access_count, 0) + 1,
    last_accessed_at = NOW()
  WHERE checkout_slug = p_slug;
  
  -- Buscar dados do checkout
  SELECT jsonb_build_object(
    'checkout_slug', cl.checkout_slug,
    'thank_you_slug', cl.thank_you_slug,
    'id', cl.id,
    'customer_name', cl.customer_name,
    'customer_email', cl.customer_email,
    'customer_document', cl.customer_document,
    'product_name', cl.product_name,
    'amount', cl.amount,
    'original_amount', cl.original_amount,
    'discount_percentage', cl.discount_percentage,
    'discount_amount', cl.discount_amount,
    'final_amount', COALESCE(cl.final_amount, cl.amount),
    'expires_at', cl.expires_at,
    'items', cl.items,
    'metadata', cl.metadata,
    'pix_qrcode', cl.pix_qrcode,
    'pix_expires_at', cl.pix_expires_at,
    'pix_generated_at', cl.pix_generated_at,
    'customer_address', cl.customer_address,
    'payment_id', p.id,
    'payment_status', p.status,
    'payment_bestfy_id', p.bestfy_id
  )
  INTO v_result
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.checkout_slug = p_slug
    AND cl.expires_at > NOW()
  LIMIT 1;
  
  RETURN v_result;
END;
$$;

-- Testar a função
SELECT get_checkout_by_slug('hxgwa8q1');

