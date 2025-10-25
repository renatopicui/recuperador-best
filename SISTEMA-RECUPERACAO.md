# Sistema de Rastreamento de Transações Recuperadas

## 📋 Visão Geral

Este sistema rastreia automaticamente quando uma transação pendente é recuperada através do sistema de checkout, permitindo que você veja métricas de recuperação no dashboard.

## 🎯 Como Funciona

### 1. **Detecção Automática**

Quando um pagamento é marcado como "pago" (`status = 'paid'`) e existe um checkout link associado a ele, o sistema automaticamente:

- Marca o campo `converted_from_recovery = true`
- Registra a data/hora em `recovered_at`
- Atualiza as estatísticas no dashboard

### 2. **Fluxo de Recuperação**

```
1. Cliente abandona carrinho (payment status = 'waiting_payment')
   ↓
2. Sistema envia email de recuperação com link do checkout
   ↓
3. Cliente acessa o checkout e gera PIX
   ↓
4. Cliente paga o PIX
   ↓
5. Sistema detecta pagamento (polling a cada 5 segundos)
   ↓
6. Sistema marca automaticamente como RECUPERADO
   ↓
7. Dashboard mostra a venda recuperada
```

### 3. **Componentes do Sistema**

#### **Migration SQL** (`20251022000000_add_recovery_tracking.sql`)
- Adiciona campos `converted_from_recovery` e `recovered_at` na tabela `payments`
- Cria função `mark_payment_as_recovered()` para marcação manual
- Cria trigger automático para marcação quando status muda para 'paid'

#### **Recovery Service** (`recoveryService.ts`)
```typescript
// Marcar manualmente como recuperado
await recoveryService.markPaymentAsRecovered(paymentId);

// Verificar se foi recuperado
const isRecovered = await recoveryService.isPaymentRecovered(paymentId);

// Obter estatísticas
const stats = await recoveryService.getRecoveryStats();
```

#### **Checkout Component** (`Checkout.tsx`)
- Monitora status do pagamento a cada 5 segundos
- Quando detecta mudança para 'paid', chama `markPaymentAsRecovered()`
- Exibe página de "Obrigado" após confirmação

#### **Dashboard** (`Dashboard.tsx`)
- **Card de Vendas Recuperadas**: Mostra quantidade e valor total
- **Seção Especial**: Lista as últimas 5 transações recuperadas
- **Badge Visual**: Badge "💰 Recuperado" nas transações recuperadas
- **Estatísticas**: Taxa de conversão, valores recuperados, etc.

## 📊 Métricas Disponíveis

O dashboard mostra:

1. **Vendas Recuperadas**: Quantidade de transações recuperadas
2. **Valores Recuperados**: Valor total em R$ das vendas recuperadas
3. **Taxa de Conversão**: (Vendas Recuperadas / E-mails Enviados) × 100
4. **Acessos ao Checkout**: Quantas vezes os links foram acessados

## 🔧 Configuração

### Aplicar Migration

Para ativar o sistema, você precisa executar a migration no Supabase:

**Via Dashboard:**
1. Acesse https://supabase.com/dashboard
2. Selecione seu projeto
3. Vá em **SQL Editor**
4. Copie o conteúdo de `supabase/migrations/20251022000000_add_recovery_tracking.sql`
5. Execute

**Via CLI:**
```bash
supabase db push
```

### Verificar se está Funcionando

1. Crie um pagamento pendente
2. Acesse o checkout link
3. Gere um PIX
4. Pague o PIX (ou simule o pagamento no ambiente de testes)
5. Aguarde até 5 segundos
6. O sistema deve automaticamente marcar como recuperado
7. Verifique no Dashboard na seção "🎉 Transações Recuperadas"

## 🎨 Visual do Dashboard

### Cards de Estatísticas
- **Verde esmeralda** para vendas recuperadas
- **Badge especial** "💰 Recuperado" nas transações
- **Seção dedicada** mostrando as últimas recuperações

### Seção de Transações Recuperadas
```
🎉 Transações Recuperadas
Vendas que foram recuperadas através do sistema de checkout

R$ 1.250,00
5 vendas recuperadas
```

## 🔍 Consultas SQL Úteis

```sql
-- Ver todas as transações recuperadas
SELECT * FROM payments 
WHERE converted_from_recovery = true 
AND status = 'paid';

-- Total recuperado por período
SELECT 
  DATE(recovered_at) as data,
  COUNT(*) as quantidade,
  SUM(amount) as total
FROM payments
WHERE converted_from_recovery = true
GROUP BY DATE(recovered_at)
ORDER BY data DESC;

-- Taxa de conversão
SELECT 
  COUNT(*) FILTER (WHERE recovery_email_sent_at IS NOT NULL) as emails_enviados,
  COUNT(*) FILTER (WHERE converted_from_recovery = true) as recuperados,
  ROUND(
    COUNT(*) FILTER (WHERE converted_from_recovery = true)::numeric / 
    NULLIF(COUNT(*) FILTER (WHERE recovery_email_sent_at IS NOT NULL), 0) * 100, 
    2
  ) as taxa_conversao
FROM payments;
```

## 🚀 Próximas Melhorias

- [ ] Gráfico de evolução de vendas recuperadas
- [ ] Notificações quando uma venda é recuperada
- [ ] Relatório mensal de recuperação
- [ ] Comparativo antes/depois do sistema de recuperação
- [ ] A/B testing de diferentes estratégias de recuperação

## 🐛 Troubleshooting

### Transação não está sendo marcada como recuperada

1. **Verifique se a migration foi aplicada:**
```sql
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'payments' 
AND column_name IN ('converted_from_recovery', 'recovered_at');
```

2. **Verifique se o trigger está ativo:**
```sql
SELECT trigger_name FROM information_schema.triggers 
WHERE trigger_name = 'trigger_auto_mark_recovered';
```

3. **Marque manualmente:**
```sql
SELECT mark_payment_as_recovered('payment-id-aqui');
```

### Estatísticas não aparecem no Dashboard

1. Limpe o cache do navegador
2. Force refresh: `Ctrl/Cmd + Shift + R`
3. Verifique o console do navegador para erros
4. Sincronize os dados: clique em "Sincronizar" no dashboard

## 📞 Suporte

Se encontrar problemas ou tiver sugestões de melhoria, verifique:
- Console do navegador para erros JavaScript
- Logs do Supabase para erros de SQL
- Network tab para verificar chamadas de API

---

**Última atualização:** 22 de Outubro de 2025

