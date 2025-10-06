/*
  # Persistir Estado do PIX no Checkout

  1. Alterações
    - Adicionar colunas para armazenar dados do PIX gerado
    - Permitir restauração automática do Step 2 após reload
    
  2. Novas Colunas
    - `pix_qrcode` (TEXT) - Código PIX copia e cola
    - `pix_expires_at` (TIMESTAMPTZ) - Quando o PIX expira
    - `pix_generated_at` (TIMESTAMPTZ) - Quando foi gerado
    
  3. Security
    - Atualizar políticas RLS para permitir acesso aos novos campos
*/

-- Add PIX persistence columns to checkout_links
ALTER TABLE checkout_links 
ADD COLUMN IF NOT EXISTS pix_qrcode TEXT,
ADD COLUMN IF NOT EXISTS pix_expires_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS pix_generated_at TIMESTAMPTZ;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_checkout_links_pix_generated 
ON checkout_links(pix_generated_at) 
WHERE pix_generated_at IS NOT NULL;

-- Drop and recreate the get_checkout_by_slug function to include PIX data
DROP FUNCTION IF EXISTS get_checkout_by_slug(TEXT);

CREATE FUNCTION get_checkout_by_slug(slug TEXT)
RETURNS TABLE (
    checkout_slug TEXT,
    user_id UUID,
    customer_name TEXT,
    customer_email TEXT,
    customer_document TEXT,
    customer_phone TEXT,
    customer_address JSONB,
    product_name TEXT,
    amount INTEGER,
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
        cl.customer_document,
        cl.customer_phone,
        cl.customer_address,
        cl.product_name,
        cl.amount,
        cl.items,
        cl.metadata,
        cl.expires_at,
        cl.payment_status,
        cl.payment_bestfy_id,
        cl.pix_qrcode,
        cl.pix_expires_at,
        cl.pix_generated_at,
        cl.access_count
    FROM checkout_links cl
    WHERE cl.checkout_slug = slug
    AND cl.expires_at > now()
    LIMIT 1;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_checkout_by_slug(TEXT) TO anon, authenticated;