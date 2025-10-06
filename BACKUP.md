# 📦 Guia de Backup Completo

## ✅ O que já está protegido automaticamente:

### 1. **Schema do Banco (Migrações)**
Todas as tabelas, funções, políticas RLS estão em:
```
supabase/migrations/*.sql
```
Estes arquivos já fazem backup completo da estrutura.

### 2. **Edge Functions**
Todas as funções serverless estão em:
```
supabase/functions/
├── bestfy-cron/
├── bestfy-sync/
├── bestfy-webhook/
├── postmark-proxy/
└── send-recovery-emails/
```

### 3. **Código Frontend**
Todo o código React está versionado em:
```
src/
├── components/
├── services/
├── types/
└── utils/
```

---

## 🔄 Como Fazer Backup dos DADOS

### Opção 1: Via Supabase Dashboard
1. Acesse: https://supabase.com/dashboard
2. Vá em: **Database** → **Backups**
3. Clique em: **Enable backups** (se ainda não ativou)
4. Configure backups diários automáticos

### Opção 2: Via SQL (Manual)
Execute no SQL Editor do Supabase:

```sql
-- Ver quantos registros existem
SELECT
  'api_keys' as table_name, COUNT(*) as records FROM api_keys
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'checkout_links', COUNT(*) FROM checkout_links
UNION ALL
SELECT 'system_settings', COUNT(*) FROM system_settings
UNION ALL
SELECT 'email_settings', COUNT(*) FROM email_settings
UNION ALL
SELECT 'webhook_logs', COUNT(*) FROM webhook_logs;
```

Para exportar dados específicos:
```sql
-- Exportar todos os pagamentos
SELECT * FROM payments;
-- Copie o resultado e salve em CSV
```

---

## 🚀 Como Restaurar o Sistema do Zero

### 1. Criar novo projeto Supabase
```bash
# Configure as variáveis de ambiente
VITE_SUPABASE_URL=<sua-nova-url>
VITE_SUPABASE_ANON_KEY=<sua-nova-chave>
```

### 2. Aplicar todas as migrações
As migrações já estão em ordem cronológica em `supabase/migrations/`.
O Supabase aplica automaticamente na ordem correta.

### 3. Deploy das Edge Functions
```bash
# O sistema já tem as functions prontas em:
supabase/functions/*
```

### 4. Configurar System Settings
```sql
UPDATE system_settings
SET value = 'https://sua-url-real.com'
WHERE key = 'APP_URL';
```

### 5. Adicionar API Key da Bestfy
Use a interface do Dashboard ou:
```sql
INSERT INTO api_keys (user_id, api_key, is_active)
VALUES (auth.uid(), 'sua-chave-bestfy', true);
```

---

## 📋 Checklist de Backup

- [ ] Código versionado no Git
- [ ] Migrações em `supabase/migrations/`
- [ ] Edge Functions em `supabase/functions/`
- [ ] Backup dos dados habilitado no Supabase
- [ ] Variáveis de ambiente documentadas (`.env`)
- [ ] Documentação atualizada

---

## ⚠️ IMPORTANTE

**Nunca versione no Git:**
- ❌ Chaves API da Bestfy
- ❌ Tokens do Postmark
- ❌ Credenciais do Supabase (já estão no dashboard)

**Sempre versione:**
- ✅ Código fonte
- ✅ Migrações SQL
- ✅ Edge Functions
- ✅ Documentação

---

## 📞 Recuperação de Desastre

Se perder tudo, você precisa apenas de:
1. Este repositório Git
2. Uma conta Supabase (gratuita)
3. Chave API da Bestfy
4. Token do Postmark

Com isso, recria o sistema completo em ~10 minutos.
