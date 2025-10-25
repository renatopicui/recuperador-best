# 🔧 SOLUÇÃO DEFINITIVA - AUTOMATIZAR CRIAÇÃO DE CHECKOUTS

## 🚨 PROBLEMA

Checkouts **NÃO** estão sendo criados automaticamente após 3 minutos.

**Sintomas:**
- ❌ Transação criada há 5+ minutos
- ❌ Checkout não existe
- ❌ Cliente não recebe email

---

## ✅ SOLUÇÃO IMEDIATA (Forçar Tudo Agora)

### Execute: `FORCAR-TODOS-CHECKOUTS-AGORA.sql` ⚡

**O que faz:**
1. ✅ Lista TODAS as transações sem checkout
2. ✅ Cria checkouts para TODAS de uma vez
3. ✅ Mostra links prontos para enviar
4. ✅ Diagnostica por que não está rodando automaticamente

**Como usar:**
```bash
1. Supabase → SQL Editor
2. Cole: FORCAR-TODOS-CHECKOUTS-AGORA.sql
3. Run ▶️
4. Veja os links criados
5. Copie e envie para os clientes
```

---

## 🔍 DIAGNÓSTICO: Por Que Não Funciona Automaticamente?

### Causa 1: Função Está Configurada para 1 Hora ❌

**Problema**: Script de expiração mudou de 3min → 1h sem querer

**Verificar:**
```sql
SELECT routine_definition 
FROM information_schema.routines
WHERE routine_name = 'generate_checkout_links_for_pending_payments';
```

Se aparecer `INTERVAL '1 hour'` → **ERRADO!**

**Solução:**
```
Execute: CORRIGIR-CHECKOUT-3MIN-EXPIRA-24H.sql
```

---

### Causa 2: Cron Job Não Está Ativo ⏰

**Problema**: Ninguém está chamando a função automaticamente

**Verificar:**
```sql
SELECT * FROM cron.job 
WHERE jobname LIKE '%checkout%';
```

Se não aparecer nada ou `active = false` → **PROBLEMA!**

**Solução**: Criar Cron Job no Supabase

---

### Causa 3: Edge Function Não Está Rodando 🔄

**Problema**: Edge Function `send-recovery-emails` não está sendo executada

**Verificar**: Supabase → Functions → `send-recovery-emails`

Se não existir → **PRECISA CRIAR!**

---

## 🎯 SOLUÇÃO PERMANENTE (3 Opções)

### Opção 1: Cron Job no Supabase ⏰ (Recomendado)

**Vantagem**: Executa automaticamente a cada X minutos

**Como configurar:**

1. **Supabase Dashboard** → Database → Cron Jobs
2. **Criar novo job**:
   - Nome: `create-checkouts-every-5min`
   - Schedule: `*/5 * * * *` (a cada 5 minutos)
   - Command: 
     ```sql
     SELECT generate_checkout_links_for_pending_payments();
     ```

---

### Opção 2: Edge Function + Cron ⚡

**Vantagem**: Pode fazer mais coisas (criar checkout + enviar email)

**Como configurar:**

1. Criar Edge Function que chama:
   - `generate_checkout_links_for_pending_payments()`
   - `send_recovery_emails()`

2. Configurar Cron para chamar a Edge Function:
   ```sql
   SELECT cron.schedule(
     'checkout-and-email-job',
     '*/5 * * * *',
     $$
     SELECT net.http_post(
       url := 'https://SEU-PROJETO.supabase.co/functions/v1/send-recovery-emails',
       headers := '{"Content-Type": "application/json"}'::jsonb
     )
     $$
   );
   ```

---

### Opção 3: Webhook da Bestfy 🔔

**Vantagem**: Executa imediatamente quando transação é criada

**Como configurar:**

1. Bestfy Dashboard → Webhooks
2. Criar webhook para evento `charge.created`
3. URL: `https://SEU-PROJETO.supabase.co/functions/v1/create-checkout-on-demand`
4. Edge Function cria checkout 3 minutos depois

---

## ⚡ CONFIGURAÇÃO RÁPIDA (Recomendada)

### Passo 1: Corrigir Função
```bash
Execute: CORRIGIR-CHECKOUT-3MIN-EXPIRA-24H.sql
```

### Passo 2: Criar Cron Job
```sql
-- No Supabase SQL Editor:
SELECT cron.schedule(
  'auto-create-checkouts',
  '*/5 * * * *',  -- A cada 5 minutos
  $$SELECT generate_checkout_links_for_pending_payments()$$
);
```

### Passo 3: Verificar Se Está Ativo
```sql
SELECT * FROM cron.job WHERE jobname = 'auto-create-checkouts';
```

Deve mostrar: `active: true` ✅

---

## 🧪 TESTAR SE ESTÁ FUNCIONANDO

### Teste Manual

1. **Criar transação**
2. **Aguardar 3-5 minutos**
3. **Verificar**:
   ```sql
   SELECT * FROM checkout_links 
   WHERE created_at > NOW() - INTERVAL '10 minutes';
   ```
4. **Deve aparecer** o checkout criado ✅

---

## 📊 MONITORAMENTO

### Query para Ver Última Execução do Cron

```sql
SELECT 
    jobname,
    last_run_time,
    last_run_status,
    next_run_time
FROM cron.job_run_details
WHERE jobname = 'auto-create-checkouts'
ORDER BY run_time DESC
LIMIT 5;
```

---

## 🚨 SE AINDA NÃO FUNCIONAR

### Debug Completo

1. **Ver transações sem checkout:**
   ```sql
   SELECT COUNT(*) 
   FROM payments p
   LEFT JOIN checkout_links cl ON cl.payment_id = p.id
   WHERE p.status = 'waiting_payment'
   AND cl.id IS NULL
   AND p.created_at < NOW() - INTERVAL '3 minutes';
   ```

2. **Executar função manualmente:**
   ```sql
   SELECT generate_checkout_links_for_pending_payments();
   ```

3. **Se retornar `{"created": 0, "errors": 0}`:**
   - ✅ Função está OK
   - ❌ Não há transações que atendem critérios
   - ⚠️ Verifique se `created_at < NOW() - INTERVAL '3 minutes'`

4. **Se retornar `{"created": X, "errors": Y}`:**
   - ✅ Criou X checkouts
   - ⚠️ Y erros (ver logs)

---

## 📋 CHECKLIST FINAL

- [ ] Executei `CORRIGIR-CHECKOUT-3MIN-EXPIRA-24H.sql`
- [ ] Função espera **3 minutos** (não 1 hora)
- [ ] Cron job está **ativo**
- [ ] Cron job roda a cada **5 minutos**
- [ ] Testei manualmente e funciona
- [ ] Checkouts expiram em **24 horas**
- [ ] Sistema cria checkouts automaticamente ✅

---

## 🎯 RESUMO EXECUTIVO

**AGORA (Urgente):**
```
Execute: FORCAR-TODOS-CHECKOUTS-AGORA.sql
→ Cria todos os checkouts pendentes AGORA
```

**DEPOIS (Permanente):**
```
1. Execute: CORRIGIR-CHECKOUT-3MIN-EXPIRA-24H.sql
2. Configure Cron Job (5 minutos)
3. Teste e monitore
```

**RESULTADO:**
```
✅ Checkouts criados automaticamente após 3 minutos
✅ Sistema funciona sozinho
✅ Clientes recebem links rapidamente
```

---

**Execute `FORCAR-TODOS-CHECKOUTS-AGORA.sql` primeiro para resolver o problema imediato!** ⚡

Depois configure o Cron Job para funcionar automaticamente! 🎯

