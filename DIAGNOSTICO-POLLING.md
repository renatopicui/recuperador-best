# 🔍 DIAGNÓSTICO: Por Que o Checkout Não Atualiza?

## ❌ Problema
Você está em `http://localhost:5173/checkout/7huoo30x` e o pagamento foi marcado como PAGO no banco, mas a página **NÃO detecta** e **NÃO redireciona**.

---

## 🧪 TESTE 1: Verificar se Polling Está Funcionando

### Abra o Console do Navegador (F12) e veja:

**Se está funcionando, você deve ver a cada 5 segundos:**
```
🔍 Verificando status do pagamento...
```

**Se NÃO aparecer nada:** O polling não está ativo!

---

## 🧪 TESTE 2: Verificar se Função SQL Existe

### Execute no Supabase SQL Editor:

```sql
-- Testar função
SELECT get_checkout_by_slug('7huoo30x');
```

**Resultado esperado:**
```json
{
  "checkout_slug": "7huoo30x",
  "payment_status": "paid",  ← DEVE MOSTRAR "paid"
  "thank_you_slug": "ty-abc123...",
  ...
}
```

**Se der erro:** A função não existe! Execute `INSTALAR-TUDO-AGORA.sql`

---

## 🧪 TESTE 3: Verificar Status no Banco

```sql
SELECT 
  cl.checkout_slug,
  p.status as payment_status,
  cl.thank_you_slug
FROM checkout_links cl
JOIN payments p ON p.id = cl.payment_id
WHERE cl.checkout_slug = '7huoo30x';
```

**Deve retornar:**
```
checkout_slug | payment_status | thank_you_slug
7huoo30x      | paid          | ty-abc123...
```

---

## ✅ SOLUÇÃO: Execute Este Script COMPLETO

Copie e execute no Supabase SQL Editor:

```sql
-- 1. Garantir que colunas existem
ALTER TABLE checkout_links ADD COLUMN IF NOT EXISTS thank_you_slug text;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS converted_from_recovery boolean DEFAULT false;

-- 2. CRIAR A FUNÇÃO get_checkout_by_slug (ESSENCIAL!)
DROP FUNCTION IF EXISTS get_checkout_by_slug(text);
CREATE OR REPLACE FUNCTION get_checkout_by_slug(p_slug text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Atualizar contador
  UPDATE checkout_links
  SET access_count = COALESCE(access_count, 0) + 1,
      last_accessed_at = NOW()
  WHERE checkout_slug = p_slug;
  
  -- Buscar dados atualizados
  SELECT jsonb_build_object(
    'checkout_slug', cl.checkout_slug,
    'thank_you_slug', cl.thank_you_slug,
    'id', cl.id,
    'customer_name', cl.customer_name,
    'customer_email', cl.customer_email,
    'customer_document', cl.customer_document,
    'product_name', cl.product_name,
    'amount', cl.amount,
    'final_amount', COALESCE(cl.final_amount, cl.amount),
    'expires_at', cl.expires_at,
    'pix_qrcode', cl.pix_qrcode,
    'payment_id', p.id,
    'payment_status', p.status,  -- ← ESTE É O CAMPO IMPORTANTE!
    'payment_bestfy_id', p.bestfy_id
  )
  INTO v_result
  FROM checkout_links cl
  JOIN payments p ON p.id = cl.payment_id
  WHERE cl.checkout_slug = p_slug
  LIMIT 1;
  
  RETURN v_result;
END;
$$;

-- 3. Gerar thank_you_slug se não existir
UPDATE checkout_links
SET thank_you_slug = 'ty-' || substr(md5(random()::text || clock_timestamp()::text), 1, 12)
WHERE checkout_slug = '7huoo30x' AND thank_you_slug IS NULL;

-- 4. Testar a função AGORA
SELECT get_checkout_by_slug('7huoo30x');

-- 5. Ver URL de obrigado
SELECT 'ACESSE: http://localhost:5173/obrigado/' || thank_you_slug 
FROM checkout_links 
WHERE checkout_slug = '7huoo30x';
```

---

## 🎯 O Que Vai Acontecer Depois

1. ✅ Função `get_checkout_by_slug()` existirá e funcionará
2. ✅ Polling vai buscar status atualizado do banco
3. ✅ Quando status = 'paid', redireciona automaticamente
4. ✅ Leva até 5 segundos para detectar

---

## 🔥 TESTE IMEDIATO

Depois de executar o script acima:

1. **Deixe a página do checkout aberta**
2. **Execute no SQL:**
   ```sql
   UPDATE payments SET status = 'paid' 
   WHERE id IN (SELECT payment_id FROM checkout_links WHERE checkout_slug = '7huoo30x');
   ```
3. **Aguarde ATÉ 5 segundos**
4. **Sistema deve redirecionar automaticamente!**

---

## 📊 Fluxo Correto

```
[Página Checkout Aberta]
      ↓ A cada 5 segundos
[Chama get_checkout_by_slug('7huoo30x')]
      ↓
[Função SQL busca no banco]
      ↓
[Retorna { payment_status: 'paid', thank_you_slug: 'ty-...' }]
      ↓
[Código detecta mudança: paid !== waiting_payment]
      ↓
[Redireciona: window.location.href = '/obrigado/ty-...']
```

---

## ⚠️ Se Ainda Não Funcionar

### Verifique no Console do Navegador:

Você DEVE ver isso a cada 5 segundos:
```javascript
checkPaymentStatus()
  → getCheckoutBySlug('7huoo30x')
    → Resultado: { payment_status: 'paid', ... }
      → 🎉 Pagamento confirmado! Redirecionando...
```

Se não aparecer, o polling não está ativo ou a função não existe.

---

**EXECUTE O SCRIPT SQL ACIMA AGORA!** 🚀

