# 📧 POR QUE O EMAIL NÃO FOI ENVIADO?

## 🔍 DIAGNÓSTICO RÁPIDO

Execute este script no Supabase SQL Editor:

**`DIAGNOSTICAR-EMAIL-NAO-ENVIADO.sql`**

---

## 🎯 POSSÍVEIS CAUSAS

### Causa 1: ❌ Postmark Não Configurado

**Sintoma:**
```
tem_email_config: NÃO
```

**Solução:**
1. Dashboard → Configurar Email
2. Insira Token do Postmark
3. Configure From Email e From Name
4. Teste o envio

---

### Causa 2: ⏳ Ainda Não Passou 1 Hora

**Sintoma:**
```
horas_desde_criacao: 0.45
diagnostico: AGUARDANDO (faltam 33 minutos)
```

**Solução:**
- ✅ **Aguardar**: Email será enviado automaticamente
- ⚡ **Forçar agora**: Execute `FORCAR-ENVIO-EMAIL-MANUAL.sql`

---

### Causa 3: ✅ Pagamento Já Foi Confirmado

**Sintoma:**
```
payment_status: paid
diagnostico: Pagamento já foi confirmado
```

**Solução:**
- ✅ **OK**: Não precisa enviar email de recuperação
- Cliente já pagou!

---

### Causa 4: 📧 Email Já Foi Enviado

**Sintoma:**
```
email_enviado: SIM
recovery_email_sent_at: 2025-10-23 15:30:00
```

**Solução:**
- ✅ **OK**: Email já foi enviado anteriormente
- Sistema não envia duplicado

---

### Causa 5: ⚠️ Cron Job Não Está Ativo

**Sintoma:**
```
Atende todos os critérios mas email não foi enviado
Cron job pode não estar ativo
```

**Solução:**
1. Verificar cron jobs no Supabase
2. Forçar envio manual (veja abaixo)

---

## 🚀 SOLUÇÕES

### Solução 1: Configurar Postmark

```
1. Dashboard
2. Configurar Email
3. Token Postmark
4. From Email: seu@email.com
5. From Name: Seu Nome
6. Salvar
```

---

### Solução 2: Aguardar 1 Hora

```
Email criado: 10:00
Email enviado: 11:00 (automaticamente)
```

O sistema verifica a cada 1 hora.

---

### Solução 3: Forçar Envio Manual

#### Opção A: Via Edge Function (Recomendado)

No Supabase Dashboard → Functions → `send-recovery-emails` → Invoke

#### Opção B: Via SQL

Execute: `FORCAR-ENVIO-EMAIL-MANUAL.sql`

---

## 📊 EXEMPLO DE DIAGNÓSTICO

### Caso 1: Tudo OK, Aguardando

```sql
customer_email: renatopicui1@gmail.com
payment_status: waiting_payment
horas_desde_criacao: 0.45
tem_email_config: SIM
tem_checkout_link: SIM
email_enviado: NÃO
diagnostico: ⏳ AGUARDANDO (faltam 33 minutos)
```

**Ação**: Aguardar ou forçar envio manual

---

### Caso 2: Postmark Não Configurado

```sql
customer_email: renatopicui1@gmail.com
payment_status: waiting_payment
horas_desde_criacao: 2.5
tem_email_config: NÃO
diagnostico: ❌ PROBLEMA: Usuário não configurou Postmark
```

**Ação**: Configurar Postmark no Dashboard

---

### Caso 3: Já Foi Enviado

```sql
customer_email: renatopicui1@gmail.com
payment_status: waiting_payment
horas_desde_criacao: 3.2
tem_email_config: SIM
email_enviado: SIM
diagnostico: ✅ Email já foi enviado
```

**Ação**: Verificar caixa de entrada do cliente

---

## 🔧 FERRAMENTAS

### 1. Diagnóstico Completo
```
DIAGNOSTICAR-EMAIL-NAO-ENVIADO.sql
```
Mostra exatamente por que não foi enviado

### 2. Forçar Envio Manual
```
FORCAR-ENVIO-EMAIL-MANUAL.sql
```
Envia email agora, sem esperar cron

### 3. Verificar Cron Jobs
```sql
SELECT * FROM cron.job 
WHERE jobname LIKE '%recovery%';
```

---

## ⏰ LINHA DO TEMPO ESPERADA

```
00:00 - Pagamento criado (waiting_payment)
00:30 - Sistema aguardando...
01:00 - ⚡ Cron job executa
01:01 - Verifica critérios:
        ✅ status = 'waiting_payment'
        ✅ passou 1 hora
        ✅ email não enviado
        ✅ Postmark configurado
01:02 - Gera checkout link (20% OFF)
01:03 - Envia email via Postmark
01:04 - Marca recovery_email_sent_at = NOW()
01:05 - ✅ Email enviado!
```

---

## 📝 CHECKLIST DE VERIFICAÇÃO

- [ ] Postmark está configurado?
- [ ] Passou 1 hora desde a criação?
- [ ] Status está `waiting_payment`?
- [ ] Email não foi enviado ainda?
- [ ] Checkout link foi criado?
- [ ] Cron job está ativo?

---

## 🎯 PRÓXIMOS PASSOS

### 1. Execute o Diagnóstico
```
DIAGNOSTICAR-EMAIL-NAO-ENVIADO.sql
```

### 2. Veja o Resultado
```
diagnostico: [mensagem aqui]
```

### 3. Siga a Solução Sugerida
- Se Postmark não configurado → Configure
- Se aguardando → Espere ou force
- Se já enviado → Verifique caixa de entrada

---

**Execute `DIAGNOSTICAR-EMAIL-NAO-ENVIADO.sql` para descobrir o problema!** 🔍

