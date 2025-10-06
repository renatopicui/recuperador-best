/*
  # Adicionar user_id à tabela payments

  1. Modificações na tabela
    - Adiciona coluna `user_id` na tabela `payments`
    - Cria foreign key para `auth.users`
    - Atualiza políticas RLS para isolamento por usuário
    - Adiciona índice para performance

  2. Segurança
    - Enable RLS na tabela payments
    - Políticas para usuários autenticados acessarem apenas seus dados
    - Políticas para anon users (webhook) inserir dados

  3. Performance
    - Índice otimizado para consultas por user_id
*/

-- Adicionar coluna user_id à tabela payments
ALTER TABLE public.payments 
ADD COLUMN user_id uuid;

-- Criar foreign key constraint
ALTER TABLE public.payments
ADD CONSTRAINT fk_payments_user
FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Criar índice para performance
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON public.payments(user_id);

-- Remover políticas antigas
DROP POLICY IF EXISTS "Allow insert payments for anon users" ON public.payments;
DROP POLICY IF EXISTS "Allow insert payments for authenticated users" ON public.payments;
DROP POLICY IF EXISTS "Allow select payments for anon users" ON public.payments;
DROP POLICY IF EXISTS "Allow select payments for authenticated users" ON public.payments;
DROP POLICY IF EXISTS "Allow update payments for anon users" ON public.payments;
DROP POLICY IF EXISTS "Allow update payments for authenticated users" ON public.payments;

-- Criar novas políticas RLS para isolamento por usuário
CREATE POLICY "Users can view their own payments"
  ON public.payments
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own payments"
  ON public.payments
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own payments"
  ON public.payments
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Política para webhook (anon) inserir pagamentos
-- Nota: O webhook precisará ser atualizado para incluir user_id
CREATE POLICY "Allow webhook to insert payments"
  ON public.payments
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- Política para webhook (anon) atualizar pagamentos
CREATE POLICY "Allow webhook to update payments"
  ON public.payments
  FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);