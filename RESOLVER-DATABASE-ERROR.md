# 🔧 RESOLVER: Database error finding user

## ❌ ERRO
```
POST .../auth/v1/signup 500 (Internal Server Error)
Database error finding user
```

---

## ✅ SOLUÇÃO EM 3 PASSOS

### **1️⃣ MAIS FÁCIL: Criar via Dashboard do Supabase** ⭐

1. **Acesse**: https://supabase.com
2. **Entre no projeto**
3. **Authentication** → **Users**
4. **Add user** (botão verde)
5. **Preencha**:
   - Email: `admin@teste.com`
   - Password: `senha123`
   - ✅ **Auto Confirm User** (IMPORTANTE!)
6. **Create user**
7. **Pronto!** ✅

### **Depois:**
- Acesse: http://localhost:5173
- Faça login com as credenciais criadas

---

### **2️⃣ Corrigir Políticas SQL**

Se o método acima não funcionar, execute no SQL Editor:

**Arquivo**: `CORRIGIR-POLITICAS-AUTH.sql`

Este script:
- Remove triggers problemáticos
- Corrige permissões
- Permite criação de usuários

---

### **3️⃣ Criar Usuário via SQL Direto**

Se ainda não funcionar, use:

**Arquivo**: `CRIAR-USUARIO-DIRETO.sql`

**IMPORTANTE**: Altere estas linhas no script:
```sql
new_email text := 'admin@teste.com';  -- ALTERAR
new_password text := 'senha123';       -- ALTERAR
```

Execute e use as credenciais criadas.

---

## 🎯 ORDEM DE TENTATIVAS

```
1ª) Criar via Dashboard Supabase    ← TENTE PRIMEIRO
     ↓ (se não funcionar)
2ª) CORRIGIR-POLITICAS-AUTH.sql     ← DEPOIS ESTE
     ↓ (se não funcionar)
3ª) CRIAR-USUARIO-DIRETO.sql        ← ÚLTIMO RECURSO
```

---

## 📋 CHECKLIST - Método Dashboard

- [ ] Acessei https://supabase.com
- [ ] Entrei no projeto
- [ ] Cliquei em Authentication
- [ ] Cliquei em Users
- [ ] Cliquei em Add user
- [ ] Escolhi "Create new user"
- [ ] Preenchi email e senha
- [ ] Marquei ✅ Auto Confirm User
- [ ] Cliquei em Create user
- [ ] Voltei para http://localhost:5173
- [ ] Fiz login com as credenciais
- [ ] Funcionou! ✅

---

## ⚠️ ATENÇÃO

**Sempre marque "Auto Confirm User"** ao criar usuário!

Isso evita ter que confirmar o email manualmente.

---

## 🔐 CREDENCIAIS SUGERIDAS

### Usuário Admin:
- **Email**: `adm@bestfybr.com.br`
- **Senha**: `admin123`

### Usuário Normal:
- **Email**: `usuario@teste.com`
- **Senha**: `senha123`

---

## 💡 POR QUE ESSE ERRO ACONTECE?

Este erro geralmente ocorre quando:
1. Há triggers no banco que falham ao criar usuário
2. RLS (Row Level Security) está mal configurado
3. Faltam permissões na tabela auth.users
4. Há conflitos com políticas existentes

A solução mais simples é **criar via Dashboard** que bypassa esses problemas.

---

## 🚨 SE NADA FUNCIONAR

1. Me envie print da aba **Authentication → Users** do Supabase
2. Execute este SQL e me envie o resultado:

```sql
SELECT 
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE schemaname = 'auth'
AND tablename = 'users';
```

---

**Tente primeiro criar via Dashboard do Supabase! É a solução mais rápida e confiável!** 🚀

