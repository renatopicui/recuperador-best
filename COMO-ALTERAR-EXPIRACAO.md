# ⏰ ALTERAR EXPIRAÇÃO DE CHECKOUTS PARA 24 HORAS

## 📋 SITUAÇÃO ATUAL

**Problema**: Checkouts expiram em **15 minutos**  
**Solução**: Alterar para **24 horas**

---

## 🚀 PASSO A PASSO (2 minutos)

### 1. **Abra o Supabase**
   - Acesse: https://supabase.com
   - Entre no seu projeto
   - Vá em **SQL Editor**

### 2. **Copie o Script**
   - Abra o arquivo: `ALTERAR-EXPIRACAO-24H.sql`
   - Copie **TODO o conteúdo** (Ctrl+A, Ctrl+C)

### 3. **Execute no Supabase**
   - Cole no SQL Editor
   - Clique em **Run** ▶️
   - Aguarde ~5 segundos

### 4. **Verifique o Resultado** ✅

Você verá várias tabelas de confirmação:

```
✅ CONFIGURAÇÃO ATUALIZADA
expires_at | (now() + '24:00:00'::interval)

📋 CHECKOUTS ATUAIS
checkout_slug | expires_at | horas_ate_expiracao | status
abc123xyz     | 2025-10-24 | 24.00               | ✅ Válido

📊 ESTATÍSTICAS
total_checkouts: 5
validos: 5
expirados: 0
media_horas_expiracao: 24.00
```

---

## ✅ O QUE O SCRIPT FAZ

1. **Altera o default da coluna `expires_at`**
   - De: `NOW() + 15 minutes`
   - Para: `NOW() + 24 hours`

2. **Atualiza a função de geração de checkouts**
   - `generate_checkout_links_for_pending_payments()`
   - Agora cria checkouts com 24h de validade

3. **Estende checkouts pendentes existentes**
   - Apenas os que ainda estão válidos
   - Apenas os que ainda estão com status `waiting_payment`

---

## 🎯 IMPACTO

### ANTES (15 minutos)
```
Cliente recebe email às 10:00
Link expira às 10:15 ❌
Cliente acessa às 10:20 → Link expirado
```

### DEPOIS (24 horas)
```
Cliente recebe email às 10:00
Link expira no dia seguinte às 10:00 ✅
Cliente tem o dia todo para pagar!
```

---

## 📊 VERIFICAR SE FUNCIONOU

Execute esta query no SQL Editor:

```sql
SELECT 
    checkout_slug,
    created_at,
    expires_at,
    ROUND(EXTRACT(EPOCH FROM (expires_at - created_at)) / 3600, 2) as horas_validade,
    CASE 
        WHEN expires_at > NOW() THEN '✅ Válido'
        ELSE '❌ Expirado'
    END as status
FROM checkout_links
WHERE created_at > NOW() - INTERVAL '1 day'
ORDER BY created_at DESC;
```

**Resultado esperado:**
- `horas_validade` deve ser **24.00**
- `status` deve ser **✅ Válido**

---

## 🔄 PRÓXIMOS CHECKOUTS

Todos os novos checkouts criados após executar o script terão:
- ✅ Expiração em **24 horas**
- ✅ Cliente tem o dia todo para pagar
- ✅ Melhor taxa de conversão

---

## ❓ SE DER ERRO

**Erro comum**: "permission denied for table checkout_links"

**Solução**: Use a conexão com `service_role` key ou execute como admin.

**Alternativa**: 
1. Vá em Supabase → Table Editor
2. Clique em `checkout_links`
3. Clique na coluna `expires_at`
4. Altere o default manualmente para: `(now() + '24:00:00'::interval)`

---

## ✅ PRONTO!

Após executar:
- ✅ Novos checkouts = 24h de validade
- ✅ Emails de recuperação = 24h
- ✅ Cliente tem mais tempo para pagar
- ✅ Maior chance de conversão

---

**Execute `ALTERAR-EXPIRACAO-24H.sql` agora!** 🚀

