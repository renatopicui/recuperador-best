# 🚨 SOLUÇÃO URGENTE - Checkout 7huoo30x

## 🎯 FAÇA ISSO AGORA (2 PASSOS)

### PASSO 1: Execute no Supabase SQL Editor

```sql
-- Gerar thank_you_slug
UPDATE checkout_links
SET thank_you_slug = 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12)
WHERE checkout_slug = '7huoo30x' AND thank_you_slug IS NULL;

-- Marcar como recuperado
UPDATE payments
SET converted_from_recovery = true, recovered_at = NOW()
WHERE id IN (SELECT payment_id FROM checkout_links WHERE checkout_slug = '7huoo30x')
  AND status = 'paid';

-- MOSTRAR URL
SELECT 'http://localhost:5173/obrigado/' || thank_you_slug as URL
FROM checkout_links WHERE checkout_slug = '7huoo30x';
```

### PASSO 2: Acesse a URL Retornada

Copie a URL que aparecer e acesse no navegador!

---

## 🔧 SOLUÇÃO DEFINITIVA (Para Funcionar Automaticamente)

Execute o script completo: **`INSTALAR-TUDO-AGORA.sql`**

Depois disso, TODOS os futuros pagamentos vão redirecionar automaticamente.

---

## 📝 Checklist

- [ ] Executei o SQL acima
- [ ] Copiei a URL retornada
- [ ] Acessei a URL no navegador
- [ ] Vi a página de obrigado
- [ ] Vou executar `INSTALAR-TUDO-AGORA.sql` para funcionamento automático

