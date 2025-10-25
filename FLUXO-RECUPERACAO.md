# 🎯 Sistema de Recuperação de Vendas - Fluxo Completo

## 📋 Visão Geral

Sistema robusto de rastreamento de vendas recuperadas usando páginas de "Obrigado" com slugs únicos para garantir métricas precisas.

## 🔄 Fluxo Completo de Recuperação

### 1. **Cliente Abandona Carrinho**
```
Status: waiting_payment
Sistema envia e-mail de recuperação após 3 minutos
```

### 2. **Cliente Acessa Checkout**
```
URL: http://localhost:5173/checkout/{checkout_slug}
Exemplo: http://localhost:5173/checkout/abhlh18m

✅ checkout_slug: código único do checkout
✅ thank_you_slug: código único gerado automaticamente para a página de obrigado
```

### 3. **Cliente Gera PIX**
```
Sistema chama Edge Function: generate-checkout-pix
PIX é gerado e armazenado no banco
Polling a cada 5 segundos verifica status do pagamento
```

### 4. **Cliente Paga o PIX**
```
Status muda de 'waiting_payment' para 'paid'
Sistema detecta mudança de status
```

### 5. **Redirecionamento Automático** 🎉
```
URL de Obrigado: http://localhost:5173/obrigado/{thank_you_slug}
Exemplo: http://localhost:5173/obrigado/ty-abc123xyz456

✅ URL DIFERENTE do checkout original
✅ Slug único e impossível de adivinhar
✅ Prefixo "ty-" (thank you) para fácil identificação
```

### 6. **Marcação como Recuperado** 💰
```sql
-- Ao acessar a página de obrigado, função SQL automática:
access_thank_you_page(thank_you_slug)
  → Incrementa contador de acesso
  → Registra data/hora do acesso
  → Marca payment.converted_from_recovery = TRUE
  → Registra payment.recovered_at = NOW()
```

### 7. **Visualização no Dashboard**
```
✅ Card "Vendas Recuperadas" com total em R$
✅ Seção especial destacando últimas recuperações
✅ Badge "💰 RECUPERADO" nas transações
✅ Métricas: Taxa de conversão, valores recuperados
```

## 🗄️ Estrutura do Banco de Dados

### Tabela: `checkout_links`

```sql
checkout_slug         text    -- Slug do checkout (acesso inicial)
thank_you_slug        text    -- Slug da página de obrigado (ÚNICO)
thank_you_accessed_at timestamptz -- Primeira vez que acessou obrigado
thank_you_access_count integer -- Quantas vezes acessou obrigado
```

### Tabela: `payments`

```sql
converted_from_recovery boolean   -- TRUE se foi recuperado
recovered_at           timestamptz -- Data/hora da recuperação
```

## 🎨 URLs do Sistema

| Tipo | Padrão | Exemplo | Quando Usar |
|------|--------|---------|-------------|
| **Checkout** | `/checkout/{checkout_slug}` | `/checkout/abhlh18m` | Link enviado no e-mail de recuperação |
| **Obrigado** | `/obrigado/{thank_you_slug}` | `/obrigado/ty-abc123xyz456` | Redirecionamento automático após pagamento |

## 🔐 Segurança e Confiabilidade

### ✅ Vantagens do Novo Sistema

1. **URLs Únicas**: Checkout e Obrigado têm slugs diferentes
2. **Rastreamento Preciso**: Só marca como recuperado ao acessar página de obrigado
3. **Impossível Falsificar**: Slugs são gerados com 12 caracteres aleatórios
4. **Auditável**: Registra data/hora e contador de acessos
5. **Fallback**: Se algo falhar, não marca como recuperado

### 🔒 Geração de Slugs

```sql
-- Checkout Slug: 8 caracteres (a-z, 0-9)
Exemplo: abhlh18m

-- Thank You Slug: prefixo "ty-" + 12 caracteres (a-z, 0-9)
Exemplo: ty-abc123xyz456

-- Garantia de unicidade via loop SQL
WHILE slug_exists LOOP
  -- gerar novo slug
END LOOP
```

## 📊 Métricas Disponíveis

### Dashboard Cards

1. **Vendas Recuperadas**
   - Quantidade total
   - Valor em R$
   - Últimas 5 transações recuperadas

2. **Taxa de Conversão**
   ```
   (Vendas Recuperadas / E-mails Enviados) × 100
   ```

3. **Acessos ao Checkout**
   - Quantas vezes os links foram clicados

4. **Valores Recuperados**
   - Soma total em R$ de todas as vendas recuperadas

## 🛠️ Instalação e Configuração

### 1. Aplicar Migrations

Execute as migrations no Supabase na ordem:

```sql
-- 1. Sistema básico de recuperação
20251022000000_add_recovery_tracking.sql

-- 2. Sistema de página de obrigado
20251022000001_add_thank_you_page_tracking.sql

-- 3. Atualizar função get_checkout
20251022000002_update_get_checkout_with_thank_you.sql
```

**Via Supabase Dashboard:**
1. Acesse https://supabase.com/dashboard
2. Selecione seu projeto
3. SQL Editor → New Query
4. Cole cada migration e execute em ordem

**Via CLI:**
```bash
cd recuperador-best
supabase db push
```

### 2. Verificar Instalação

```sql
-- Verificar se colunas foram criadas
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'checkout_links' 
  AND column_name IN ('thank_you_slug', 'thank_you_accessed_at', 'thank_you_access_count');

-- Verificar se funções existem
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name IN ('generate_thank_you_slug', 'access_thank_you_page', 'get_thank_you_page');
```

### 3. Testar o Fluxo

```bash
# 1. Criar uma venda pendente (via Bestfy ou manualmente no banco)

# 2. Verificar que checkout_link foi criado com thank_you_slug
SELECT checkout_slug, thank_you_slug FROM checkout_links WHERE payment_id = 'SEU_PAYMENT_ID';

# 3. Acessar o checkout
http://localhost:5173/checkout/{checkout_slug}

# 4. Gerar PIX e pagar (ou simular no banco)
UPDATE payments SET status = 'paid' WHERE id = 'SEU_PAYMENT_ID';

# 5. Sistema deve redirecionar automaticamente para:
http://localhost:5173/obrigado/{thank_you_slug}

# 6. Verificar que foi marcado como recuperado
SELECT bestfy_id, converted_from_recovery, recovered_at 
FROM payments 
WHERE id = 'SEU_PAYMENT_ID';
```

## 🎯 Comportamento Esperado

### ✅ Quando DEVE marcar como recuperado

- Cliente acessa checkout via link de e-mail
- Cliente gera PIX
- Cliente paga o PIX
- Sistema detecta pagamento
- Cliente é redirecionado para `/obrigado/{thank_you_slug}`
- **AO ACESSAR a página de obrigado** → Marca como recuperado

### ❌ Quando NÃO deve marcar como recuperado

- Cliente paga direto pela Bestfy (sem passar pelo nosso checkout)
- Pagamento foi pago antes de enviar e-mail de recuperação
- Cliente acessa checkout mas não paga
- Pagamento está pendente

## 📈 Consultas SQL Úteis

### Ver todas as vendas recuperadas

```sql
SELECT 
  p.bestfy_id,
  p.customer_name,
  p.product_name,
  p.amount / 100 as valor_real,
  p.recovered_at,
  cl.thank_you_accessed_at,
  cl.thank_you_access_count
FROM payments p
JOIN checkout_links cl ON cl.payment_id = p.id
WHERE p.converted_from_recovery = true
ORDER BY p.recovered_at DESC;
```

### Relatório de conversão por dia

```sql
SELECT 
  DATE(recovered_at) as data,
  COUNT(*) as vendas_recuperadas,
  SUM(amount) / 100 as valor_total_real,
  AVG(amount) / 100 as ticket_medio
FROM payments
WHERE converted_from_recovery = true
GROUP BY DATE(recovered_at)
ORDER BY data DESC;
```

### Checkouts com mais acessos (possível fraude)

```sql
SELECT 
  cl.checkout_slug,
  cl.thank_you_slug,
  cl.thank_you_access_count,
  p.customer_name,
  p.customer_email,
  cl.thank_you_accessed_at
FROM checkout_links cl
JOIN payments p ON p.id = cl.payment_id
WHERE cl.thank_you_access_count > 5
ORDER BY cl.thank_you_access_count DESC;
```

### Taxa de conversão geral

```sql
SELECT 
  COUNT(*) FILTER (WHERE recovery_email_sent_at IS NOT NULL) as emails_enviados,
  COUNT(*) FILTER (WHERE converted_from_recovery = true) as vendas_recuperadas,
  ROUND(
    COUNT(*) FILTER (WHERE converted_from_recovery = true)::numeric / 
    NULLIF(COUNT(*) FILTER (WHERE recovery_email_sent_at IS NOT NULL), 0) * 100, 
    2
  ) || '%' as taxa_conversao
FROM payments;
```

## 🐛 Troubleshooting

### Problema: Redirecionamento não funciona

**Possíveis causas:**
1. Migration não foi aplicada
2. Checkout antigo não tem `thank_you_slug`

**Solução:**
```sql
-- Gerar thank_you_slug para checkouts antigos
UPDATE checkout_links
SET thank_you_slug = generate_thank_you_slug()
WHERE thank_you_slug IS NULL;
```

### Problema: Não está marcando como recuperado

**Verificar:**
```sql
-- 1. Função existe?
SELECT routine_name FROM information_schema.routines 
WHERE routine_name = 'access_thank_you_page';

-- 2. Trigger existe?
SELECT trigger_name FROM information_schema.triggers 
WHERE trigger_name = 'trigger_generate_thank_you_slug';

-- 3. Marcar manualmente
SELECT access_thank_you_page('ty-seu-slug-aqui');
```

### Problema: Dashboard não mostra recuperadas

1. Limpar cache: `Ctrl/Cmd + Shift + R`
2. Verificar no banco:
```sql
SELECT COUNT(*) FROM payments WHERE converted_from_recovery = true;
```
3. Clicar em "Sincronizar" no dashboard

## 🚀 Próximas Melhorias

- [ ] Notificação em tempo real quando venda é recuperada
- [ ] Gráfico de evolução de recuperação ao longo do tempo
- [ ] A/B testing de diferentes descontos/ofertas
- [ ] Relatório detalhado de origem dos acessos
- [ ] Webhook para notificar sistema externo de recuperação

## 📞 Suporte

### Logs Importantes

**Console do Navegador:**
```
🎉 Pagamento confirmado! Redirecionando para página de obrigado...
✅ Redirecionando para: /obrigado/ty-abc123xyz456
```

**Logs SQL:**
```
✅ [ThankYou] Página acessada
✅ Transação marcada como recuperada
```

### Monitoramento

Verificar regularmente:
- Taxa de conversão está melhorando?
- Há checkouts com muitos acessos (fraude)?
- Todos os thank_you_slugs são únicos?

---

**Sistema implementado em:** 22 de Outubro de 2025  
**Versão:** 2.0 - Thank You Page Tracking

