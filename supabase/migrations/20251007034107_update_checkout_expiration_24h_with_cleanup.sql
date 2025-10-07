/*
  # Atualizar Expiração de Checkouts para 24 Horas com Limpeza Automática

  1. Modificações
    - Manter expires_at em 24 horas (já está configurado assim)
    - Criar função de limpeza automática para checkouts não pagos após 24h
    - Manter checkouts com pagamento confirmado (status = 'paid')
    - Excluir apenas checkouts expirados sem pagamento ou sem PIX gerado

  2. Regras de Limpeza
    - Remove checkouts com status 'waiting_payment' após 24h
    - Mantém checkouts com status 'paid' indefinidamente (página de obrigado)
    - Remove apenas se não houver PIX gerado OU se houver PIX mas não foi pago

  3. Atualização da função get_checkout_by_slug
    - Permitir acesso mesmo após expiração se pagamento foi confirmado
    - Bloquear acesso apenas se expirado E não pago
*/

-- Criar função de limpeza automática de checkouts expirados
CREATE OR REPLACE FUNCTION cleanup_expired_checkouts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count integer := 0;
BEGIN
  -- Remove checkouts expirados que:
  -- 1. Estão com status 'waiting_payment' (não foram pagos)
  -- 2. Já passaram de 24 horas desde a criação
  DELETE FROM checkout_links cl
  WHERE cl.expires_at < NOW()
    AND EXISTS (
      SELECT 1 FROM payments p
      WHERE p.id = cl.payment_id
        AND p.status = 'waiting_payment'
    );
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  RETURN jsonb_build_object(
    'success', true,
    'deleted_checkouts', v_deleted_count,
    'timestamp', NOW()
  );
END;
$$;

-- Atualizar função get_checkout_by_slug para permitir acesso a checkouts pagos mesmo após expiração
CREATE OR REPLACE FUNCTION get_checkout_by_slug(slug text)
RETURNS TABLE (
  checkout_slug text,
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
    AND (
      -- Permite acesso se ainda não expirou
      cl.expires_at > NOW()
      OR
      -- OU se o pagamento foi confirmado (página de obrigado)
      p.status = 'paid'
    );
END;
$$;

COMMENT ON FUNCTION cleanup_expired_checkouts() IS 'Remove checkouts expirados (>24h) que não foram pagos. Mantém checkouts com pagamento confirmado para exibição da página de obrigado.';