/*
  # Drop all tables - Clean Slate

  1. Tables to Drop
    - Drop checkout_links (has foreign keys)
    - Drop payments
    - Drop api_keys
  
  2. Functions to Drop
    - Drop all custom functions

  3. Policies to Drop
    - All RLS policies will be dropped automatically with tables
*/

-- Drop tables in correct order (respecting foreign keys)
DROP TABLE IF EXISTS checkout_links CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS api_keys CASCADE;

-- Drop all custom functions
DROP FUNCTION IF EXISTS check_bestfy_ids_exist(text[]) CASCADE;
DROP FUNCTION IF EXISTS get_api_key_for_checkout(uuid) CASCADE;
DROP FUNCTION IF EXISTS generate_checkout_link(uuid) CASCADE;
DROP FUNCTION IF EXISTS send_recovery_emails() CASCADE;