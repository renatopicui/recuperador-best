# 🔄 RECOMEÇAR DO ZERO

## 🎯 OBJETIVO
Limpar todos os dados mas manter a estrutura completa do banco.

---

## 📋 PASSO A PASSO

### **1. Limpar o Banco**

**Execute no Supabase SQL Editor:**

1. Acesse: https://supabase.com
2. Projeto: `daezmxodmvcbmturedcz`
3. SQL Editor
4. Copie: `LIMPAR-BANCO-DADOS.sql` (TODO)
5. Cole e Run
6. Aguarde "Success" ✅

**Resultado:**
```
✅ APÓS LIMPEZA
payments       → 0 registros → ✅ LIMPO
checkout_links → 0 registros → ✅ LIMPO
api_keys       → 0 registros → ✅ LIMPO
profiles       → 0 registros → ✅ LIMPO
auth.users     → 0 registros → ✅ LIMPO

📋 ESTRUTURA MANTIDA
payments       → X colunas → ✅ OK
checkout_links → X colunas → ✅ OK
api_keys       → X colunas → ✅ OK
profiles       → X colunas → ✅ OK
```

---

### **2. Corrigir o Bug do Sign Up**

**Execute no Supabase SQL Editor:**

Arquivo: `INVESTIGAR-E-CORRIGIR-BUG-SIGNUP.sql`

Isso garante que o Sign Up funcione corretamente.

---

### **3. Criar Primeiro Usuário**

**Via Sign Up no App:**

1. Acesse: http://localhost:5173
2. Sign Up (criar conta)
3. Preencha:
   ```
   Email: seu-email@exemplo.com
   Nome: Seu Nome
   Telefone: 11999998888
   Senha: sua-senha
   ```
4. Cadastrar
5. Deve funcionar! ✅

---

### **4. Configurar Chave API da Bestfy**

Após fazer login:

1. Modal abrirá pedindo chave da Bestfy
2. Cole sua chave API
3. Salvar
4. Pronto! ✅

---

## 🧹 O QUE FOI LIMPO

### **Dados Removidos:**
- ❌ Todos os pagamentos
- ❌ Todos os checkouts
- ❌ Todas as API keys
- ❌ Todos os profiles
- ❌ Todos os usuários

### **Estrutura Mantida:**
- ✅ Tabelas (com todas as colunas)
- ✅ Índices
- ✅ Foreign keys
- ✅ Políticas RLS
- ✅ Triggers
- ✅ Funções SQL
- ✅ Migrations aplicadas

---

## 📊 COMPARAÇÃO

### **ANTES (Limpar):**
```sql
DROP TABLE payments;           ❌ Remove tudo
DROP FUNCTION get_checkout;    ❌ Perde estrutura
```

### **AGORA (Limpar dados):**
```sql
TRUNCATE TABLE payments;       ✅ Mantém tabela
-- Funções preservadas          ✅ Tudo intacto
```

---

## ✅ ORDEM DE EXECUÇÃO

```
1. LIMPAR-BANCO-DADOS.sql
   └─ Remove todos os dados
   └─ Mantém estrutura

2. INVESTIGAR-E-CORRIGIR-BUG-SIGNUP.sql
   └─ Corrige trigger problemático
   └─ Garante Sign Up funcional

3. Testar no App
   └─ Sign Up deve funcionar
   └─ Sistema pronto para uso
```

---

## 🎯 CHECKLIST

- [ ] Executei `LIMPAR-BANCO-DADOS.sql`
- [ ] Vi "✅ LIMPO" em todas as tabelas
- [ ] Estrutura está mantida
- [ ] Executei `INVESTIGAR-E-CORRIGIR-BUG-SIGNUP.sql`
- [ ] Testei Sign Up no app
- [ ] Criou usuário com sucesso
- [ ] Configurei API Key da Bestfy
- [ ] Sistema funcionando! ✅

---

## 🚀 ESTADO FINAL

**Banco de Dados:**
- ✅ Limpo (zero registros)
- ✅ Estrutura completa
- ✅ Pronto para uso

**Sistema:**
- ✅ Sign Up funcionando
- ✅ Trigger correto
- ✅ Sem bugs
- ✅ Pronto para testes

**Próximos Passos:**
1. Criar usuário via Sign Up
2. Configurar API Bestfy
3. Testar fluxo completo
4. Sistema em produção! 🎉

---

## 💡 DICA

**Sempre que quiser recomeçar:**
1. Execute `LIMPAR-BANCO-DADOS.sql`
2. Banco volta ao estado zero
3. Estrutura permanece intacta
4. Pronto para novos testes

---

**Execute os scripts na ordem e comece do zero com banco limpo!** 🚀

