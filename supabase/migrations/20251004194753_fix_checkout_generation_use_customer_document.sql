/*
  # Fix Checkout Generation to Use customer_document

  1. Problem
    - The function `generate_checkout_links_for_pending_payments` was using `customer_phone` as `customer_document`
    - This caused checkout links to be created without proper CPF data
    - Recovery emails sent to customers had checkouts without CPF, causing validation errors

  2. Solution
    - Update the function to use the correct `customer_document` field from payments table
    - This ensures checkout links contain the customer's CPF for validation

  3. Changes
    - Recreate `generate_checkout_links_for_pending_payments` function
    - Change line that selects `customer_phone as customer_document` to select `customer_document`
*/

-- Drop and recreate the function with the correct field
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
        checkout_slug,
        customer_name,
        customer_email,
        customer_document,
        product_name,
        amount
      ) VALUES (
        v_payment.id,
        v_new_slug,
        v_payment.customer_name,
        v_payment.customer_email,
        v_payment.customer_document,
        v_payment.product_name,
        v_payment.amount
      );

      v_created_count := v_created_count + 1;
      RAISE NOTICE '✅ Checkout link created: % for payment % with CPF: %',
        v_new_slug, v_payment.bestfy_id, v_payment.customer_document;

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
