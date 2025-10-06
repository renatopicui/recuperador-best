/*
  # Create Automatic Checkout Link Generation Function

  1. Functions
    - `generate_checkout_links_for_pending_payments()` - Main function to create checkout links
      - Finds payments pending for more than 3 minutes
      - Only PIX payments without existing checkout links
      - Creates a unique checkout link for each payment
      - Returns summary with created count
      
  2. Automation
    - This function will be called by pg_cron every minute
    - Only creates links for payments that don't have one yet
    - Links expire after 24 hours automatically
    
  3. Notes
    - Skips payments that already have a checkout link
    - Generates unique 8-character slugs
    - Copies all relevant data from payment to checkout_link
*/

CREATE OR REPLACE FUNCTION generate_checkout_links_for_pending_payments()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_payment RECORD;
  v_new_slug text;
  v_created_count integer := 0;
  v_errors integer := 0;
  v_error_message text;
BEGIN
  -- Loop through eligible payments (pending > 3 min, no checkout link yet)
  FOR v_payment IN
    SELECT 
      p.id,
      p.bestfy_id,
      p.customer_name,
      p.customer_email,
      p.customer_document,
      p.product_name,
      p.amount,
      p.items,
      p.metadata
    FROM payments p
    WHERE p.status = 'waiting_payment'
      AND p.payment_method = 'pix'
      AND p.created_at < (NOW() - INTERVAL '3 minutes')
      AND NOT EXISTS (
        SELECT 1 
        FROM checkout_links cl 
        WHERE cl.payment_id = p.id
      )
  LOOP
    BEGIN
      -- Generate unique slug
      v_new_slug := generate_checkout_slug();
      
      -- Create checkout link
      INSERT INTO checkout_links (
        payment_id,
        checkout_slug,
        customer_name,
        customer_email,
        customer_document,
        product_name,
        amount,
        items,
        metadata
      ) VALUES (
        v_payment.id,
        v_new_slug,
        v_payment.customer_name,
        v_payment.customer_email,
        v_payment.customer_document,
        v_payment.product_name,
        v_payment.amount,
        v_payment.items,
        v_payment.metadata
      );
      
      v_created_count := v_created_count + 1;
      
      RAISE NOTICE '✅ Checkout link created: % for payment %', v_new_slug, v_payment.bestfy_id;
      
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      v_error_message := SQLERRM;
      RAISE WARNING '❌ Error creating checkout for payment %: %', v_payment.bestfy_id, v_error_message;
    END;
  END LOOP;
  
  -- Return summary
  RETURN jsonb_build_object(
    'success', true,
    'checkout_links_created', v_created_count,
    'errors', v_errors,
    'timestamp', NOW()
  );
END;
$$;

-- Function to get checkout link details by slug (for frontend)
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
  -- Increment access count
  PERFORM increment_checkout_access(slug);
  
  -- Return checkout details with payment status
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
    AND cl.expires_at > NOW();
END;
$$;