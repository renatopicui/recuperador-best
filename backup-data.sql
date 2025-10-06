-- BACKUP DE DADOS - Execute no Supabase SQL Editor
-- Data: 2025-10-04

-- Backup de API Keys
SELECT 'API Keys:', COUNT(*) FROM api_keys;
COPY (SELECT * FROM api_keys) TO STDOUT WITH CSV HEADER;

-- Backup de Payments
SELECT 'Payments:', COUNT(*) FROM payments;
COPY (SELECT * FROM payments) TO STDOUT WITH CSV HEADER;

-- Backup de Checkout Links
SELECT 'Checkout Links:', COUNT(*) FROM checkout_links;
COPY (SELECT * FROM checkout_links) TO STDOUT WITH CSV HEADER;

-- Backup de System Settings
SELECT 'System Settings:', COUNT(*) FROM system_settings;
COPY (SELECT * FROM system_settings) TO STDOUT WITH CSV HEADER;

-- Backup de Email Settings
SELECT 'Email Settings:', COUNT(*) FROM email_settings;
COPY (SELECT * FROM email_settings) TO STDOUT WITH CSV HEADER;

-- Backup de Webhook Logs
SELECT 'Webhook Logs:', COUNT(*) FROM webhook_logs;
COPY (SELECT * FROM webhook_logs) TO STDOUT WITH CSV HEADER;
