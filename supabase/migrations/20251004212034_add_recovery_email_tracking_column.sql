/*
  # Adicionar Coluna de Rastreamento de Email de Recuperação

  1. Objetivo
    - Adicionar coluna para rastrear quando o email de recuperação foi enviado
    - Permitir que o sistema saiba quais pagamentos já receberam email

  2. Nova Coluna
    - recovery_email_sent_at: timestamp com timezone, nullable
    - Armazena quando o email de recuperação foi enviado
    - NULL = email ainda não foi enviado

  3. Segurança
    - Sem mudanças nas políticas RLS
*/

-- Add recovery_email_sent_at column to track when recovery email was sent
ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS recovery_email_sent_at timestamptz DEFAULT NULL;

-- Add index for faster queries on recovery email status
CREATE INDEX IF NOT EXISTS idx_payments_recovery_email 
ON payments(recovery_email_sent_at, status, payment_method, created_at) 
WHERE recovery_email_sent_at IS NULL AND status = 'waiting_payment';

-- Add comment to document the column
COMMENT ON COLUMN payments.recovery_email_sent_at IS 'Timestamp when the recovery email was sent to the customer';
