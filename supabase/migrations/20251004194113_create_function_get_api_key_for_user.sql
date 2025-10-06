/*
  # Create Function to Get API Key for Checkout Payment Processing

  1. New Functions
    - `get_api_key_for_user(user_uuid)` - Returns encrypted API key for a user
      - Used by public checkout pages to process payments
      - Only returns Bestfy API key (not Postmark)
      - Returns encrypted key (Base64 encoded)
    
  2. Security
    - Function uses SECURITY DEFINER (elevated privileges)
    - Only returns active Bestfy keys
    - Key remains encrypted in transit
    - No authentication required (public checkout access)
    
  3. Notes
    - This function is called from the public checkout page
    - The checkout page decrypts the key on the client side
    - Used to create payment transactions via Bestfy API
*/

-- Drop if exists
DROP FUNCTION IF EXISTS get_api_key_for_user(uuid);

-- Create function to get API key for a specific user
CREATE OR REPLACE FUNCTION get_api_key_for_user(user_uuid uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  api_key text;
BEGIN
  -- Get active Bestfy API key for the user
  SELECT encrypted_key INTO api_key
  FROM api_keys
  WHERE user_id = user_uuid
    AND service = 'bestfy'
    AND is_active = true
  LIMIT 1;
  
  RETURN api_key;
END;
$$;