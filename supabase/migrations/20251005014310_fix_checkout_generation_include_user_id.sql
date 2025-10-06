/*
  # Fix Checkout Generation to Include user_id
  
  1. Problem
    - The function `generate_checkout_links_for_pending_payments` creates checkouts without user_id
    - This causes the checkout page to fail when trying to fetch API keys (needs user_id)
    - Recovery checkouts cannot process payments without knowing which user's API key to use
  
  2. Solution
    - Update the function to include user_id from the payment record
    - Ensure all new checkouts have the correct user_id associated
  
  3. Changes
    - Recreate `generate_checkout_links_for_pending_payments` function
    - Add user_id field to SELECT and INSERT statements
*/

-- Drop and recreate the function with user_id included
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
  FOR v_payment IN
    SELECT
      p.id,
      p.user_id,
      p.bestfy_id,
      p.customer_name,
      p.customer_email,
      p.customer_document,
      p.product_name,
      p.amount
    FROM payments p
    WHERE p.status = 'waiting_payment'
      AND p.payment_method = 'pix'
      AND p.created_at < (NOW() - INTERVAL '3 minutes')
      AND p.user_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM checkout_links cl
        WHERE cl.payment_id = p.id
      )
  LOOP
    BEGIN
      v_new_slug := generate_checkout_slug();

      INSERT INTO checkout_links (
        payment_id,
        user_id,
        checkout_slug,
        customer_name,
        customer_email,
        customer_document,
        product_name,
        amount
      ) VALUES (
        v_payment.id,
        v_payment.user_id,
        v_new_slug,
        v_payment.customer_name,
        v_payment.customer_email,
        v_payment.customer_document,
        v_payment.product_name,
        v_payment.amount
      );

      v_created_count := v_created_count + 1;
      RAISE NOTICE '✅ Checkout link created: % for payment % (user: %)',
        v_new_slug, v_payment.bestfy_id, v_payment.user_id;

    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      v_error_message := SQLERRM;
      RAISE WARNING '❌ Error creating checkout for payment %: %', v_payment.bestfy_id, v_error_message;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'checkout_links_created', v_created_count,
    'errors', v_errors,
    'timestamp', NOW()
  );
END;
$$;
