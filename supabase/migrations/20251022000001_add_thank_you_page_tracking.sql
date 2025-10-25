/*
  # Sistema de Confirmação de Recuperação via Página de Obrigado
  
  1. Adiciona slug único para página de "Obrigado"
  2. Rastreia quando o cliente acessa a página de obrigado
  3. Marca transação como recuperada SOMENTE quando acessa página de obrigado
*/

-- Adicionar campos para rastreamento de página de obrigado
ALTER TABLE checkout_links 
ADD COLUMN IF NOT EXISTS thank_you_slug text UNIQUE,
ADD COLUMN IF NOT EXISTS thank_you_accessed_at timestamptz,
ADD COLUMN IF NOT EXISTS thank_you_access_count integer DEFAULT 0;

-- Criar índice para busca rápida por thank_you_slug
CREATE INDEX IF NOT EXISTS idx_checkout_links_thank_you_slug ON checkout_links(thank_you_slug);

-- Atualizar função generate_checkout_slug para também gerar thank_you_slug
CREATE OR REPLACE FUNCTION generate_thank_you_slug()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  chars text := 'abcdefghijklmnopqrstuvwxyz0123456789';
  result text := '';
  i integer;
  slug_exists boolean := true;
BEGIN
  WHILE slug_exists LOOP
    result := 'ty-'; -- prefixo "ty" para "thank you"
    FOR i IN 1..12 LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    
    SELECT EXISTS(SELECT 1 FROM checkout_links WHERE thank_you_slug = result) INTO slug_exists;
  END LOOP;
  
  RETURN result;
END;
$$;

-- Trigger para gerar thank_you_slug automaticamente ao criar checkout
CREATE OR REPLACE FUNCTION auto_generate_thank_you_slug()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.thank_you_slug IS NULL THEN
    NEW.thank_you_slug := generate_thank_you_slug();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_generate_thank_you_slug ON checkout_links;
CREATE TRIGGER trigger_generate_thank_you_slug
  BEFORE INSERT ON checkout_links
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_thank_you_slug();

-- Atualizar checkouts existentes para ter thank_you_slug
UPDATE checkout_links
SET thank_you_slug = generate_thank_you_slug()
WHERE thank_you_slug IS NULL;

-- Função para acessar página de obrigado e marcar como recuperado
CREATE OR REPLACE FUNCTION access_thank_you_page(p_thank_you_slug text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_checkout_link RECORD;
  v_payment_id uuid;
BEGIN
  -- Buscar o checkout link
  SELECT 
    cl.id,
    cl.payment_id,
    cl.customer_name,
    cl.customer_email,
    cl.product_name,
    cl.amount,
    cl.final_amount,
    p.status as payment_status,
    p.bestfy_id
  INTO v_checkout_link
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.thank_you_slug = p_thank_you_slug;
  
  -- Se não encontrou, retornar erro
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Thank you page not found'
    );
  END IF;
  
  -- Incrementar contador de acesso à página de obrigado
  UPDATE checkout_links
  SET 
    thank_you_access_count = thank_you_access_count + 1,
    thank_you_accessed_at = NOW()
  WHERE thank_you_slug = p_thank_you_slug;
  
  -- Se o pagamento está pago e ainda não foi marcado como recuperado, marcar agora
  IF v_checkout_link.payment_status = 'paid' THEN
    UPDATE payments
    SET 
      converted_from_recovery = true,
      recovered_at = COALESCE(recovered_at, NOW())
    WHERE id = v_checkout_link.payment_id
      AND (converted_from_recovery IS NULL OR converted_from_recovery = false);
    
    RETURN jsonb_build_object(
      'success', true,
      'payment_recovered', true,
      'checkout_data', jsonb_build_object(
        'customer_name', v_checkout_link.customer_name,
        'customer_email', v_checkout_link.customer_email,
        'product_name', v_checkout_link.product_name,
        'amount', v_checkout_link.final_amount,
        'bestfy_id', v_checkout_link.bestfy_id
      )
    );
  END IF;
  
  -- Se o pagamento ainda não está pago
  RETURN jsonb_build_object(
    'success', true,
    'payment_recovered', false,
    'payment_status', v_checkout_link.payment_status,
    'checkout_data', jsonb_build_object(
      'customer_name', v_checkout_link.customer_name,
      'product_name', v_checkout_link.product_name
    )
  );
END;
$$;

-- Função para obter dados da página de obrigado
CREATE OR REPLACE FUNCTION get_thank_you_page(p_thank_you_slug text)
RETURNS TABLE (
  thank_you_slug text,
  customer_name text,
  customer_email text,
  product_name text,
  amount numeric,
  final_amount numeric,
  payment_status text,
  payment_bestfy_id text,
  checkout_slug text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cl.thank_you_slug,
    cl.customer_name,
    cl.customer_email,
    cl.product_name,
    cl.amount,
    COALESCE(cl.final_amount, cl.amount) as final_amount,
    p.status as payment_status,
    p.bestfy_id as payment_bestfy_id,
    cl.checkout_slug
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.thank_you_slug = p_thank_you_slug;
END;
$$;

-- Comentários
COMMENT ON COLUMN checkout_links.thank_you_slug IS 'Slug único para a página de obrigado após pagamento';
COMMENT ON COLUMN checkout_links.thank_you_accessed_at IS 'Data/hora do primeiro acesso à página de obrigado';
COMMENT ON COLUMN checkout_links.thank_you_access_count IS 'Número de vezes que a página de obrigado foi acessada';
COMMENT ON FUNCTION access_thank_you_page IS 'Registra acesso à página de obrigado e marca pagamento como recuperado se pago';
COMMENT ON FUNCTION get_thank_you_page IS 'Retorna dados para exibir na página de obrigado';

