/*
  # Adicionar constraint UNIQUE no bestfy_id
  
  Esta migração garante que cada transação da Bestfy seja única no banco de dados,
  prevenindo duplicatas.
  
  ## Mudanças
  
  1. Remove duplicatas existentes (mantém a mais recente)
  2. Adiciona constraint UNIQUE no campo bestfy_id
  3. Isso força que o webhook use UPSERT corretamente
  
  ## Segurança
  
  - Dados duplicados são mesclados mantendo o registro mais recente
  - A constraint garante integridade dos dados
*/

-- Primeiro, vamos remover duplicatas mantendo apenas o registro mais recente
DELETE FROM payments a USING payments b
WHERE a.bestfy_id = b.bestfy_id 
  AND a.id < b.id;

-- Agora adiciona a constraint UNIQUE no bestfy_id
ALTER TABLE payments 
  DROP CONSTRAINT IF EXISTS payments_bestfy_id_unique;

ALTER TABLE payments 
  ADD CONSTRAINT payments_bestfy_id_unique UNIQUE (bestfy_id);

-- Criar índice para performance em consultas por bestfy_id
CREATE INDEX IF NOT EXISTS idx_payments_bestfy_id_unique 
  ON payments(bestfy_id);
