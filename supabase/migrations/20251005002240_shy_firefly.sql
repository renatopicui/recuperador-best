/*
  # Fix Checkout Database Schema

  1. Missing Columns
    - Add `payment_bestfy_id` column to checkout_links table
    - Add `payment_status` column to checkout_links table  
    - Add `last_status_check` column to checkout_links table

  2. Missing Function
    - Create `force_sync_checkout` function to sync checkout status with payment
    - Function accepts slug parameter and updates checkout status based on payment

  3. Security
    - Update RLS policies to allow access to new columns
    - Ensure proper permissions for the new function
*/

-- Add missing columns to checkout_links table
ALTER TABLE checkout_links 
ADD COLUMN IF NOT EXISTS payment_bestfy_id TEXT,
ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'waiting_payment',
ADD COLUMN IF NOT EXISTS last_status_check TIMESTAMPTZ DEFAULT now();

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_checkout_links_payment_bestfy_id 
ON checkout_links(payment_bestfy_id);

-- Create the force_sync_checkout function
CREATE OR REPLACE FUNCTION force_sync_checkout(slug TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    checkout_record RECORD;
    payment_record RECORD;
    result JSON;
BEGIN
    -- Get checkout link by slug
    SELECT * INTO checkout_record
    FROM checkout_links
    WHERE checkout_slug = slug
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Checkout not found',
            'slug', slug
        );
    END IF;
    
    -- Get payment by bestfy_id if we have one
    IF checkout_record.payment_bestfy_id IS NOT NULL THEN
        SELECT * INTO payment_record
        FROM payments
        WHERE bestfy_id = checkout_record.payment_bestfy_id
        LIMIT 1;
        
        IF FOUND THEN
            -- Update checkout status based on payment status
            UPDATE checkout_links
            SET 
                payment_status = payment_record.status,
                last_status_check = now()
            WHERE checkout_slug = slug;
            
            -- If payment is paid and this is a recovery checkout, mark as converted
            IF payment_record.status = 'paid' AND 
               (payment_record.recovery_source = 'recovery_checkout' OR 
                payment_record.recovery_checkout_link_id IS NOT NULL) THEN
                
                UPDATE payments
                SET converted_from_recovery = true
                WHERE bestfy_id = checkout_record.payment_bestfy_id;
                
                RETURN json_build_object(
                    'success', true,
                    'message', 'Checkout synced and marked as recovery conversion',
                    'payment_status', payment_record.status,
                    'marked_as_recovery', true
                );
            END IF;
            
            RETURN json_build_object(
                'success', true,
                'message', 'Checkout status synced successfully',
                'payment_status', payment_record.status,
                'marked_as_recovery', false
            );
        END IF;
    END IF;
    
    -- If no payment found, just update the timestamp
    UPDATE checkout_links
    SET last_status_check = now()
    WHERE checkout_slug = slug;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Checkout timestamp updated, no payment found',
        'payment_status', checkout_record.payment_status
    );
END;
$$;

-- Update RLS policies to allow access to new columns
DROP POLICY IF EXISTS "Users can read own checkout links" ON checkout_links;
CREATE POLICY "Users can read own checkout links"
ON checkout_links FOR SELECT
TO authenticated
USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Anyone can update checkout access tracking" ON checkout_links;
CREATE POLICY "Anyone can update checkout access tracking"
ON checkout_links FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION force_sync_checkout(TEXT) TO anon, authenticated;