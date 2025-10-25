# 🔐 RESOLVER PROBLEMA DE LOGIN

## ❌ ERRO ATUAL
```
POST .../auth/v1/token?grant_type=password 401 (Unauthorized)
```

**Significa**: Email ou senha incorretos, ou usuário não existe.

---

## ✅ SOLUÇÃO 1: Criar Usuário via Dashboard do Supabase (MAIS FÁCIL)

### **Passo a Passo:**

1. **Acesse**: https://supabase.com
2. **Entre no seu projeto**
3. **Clique em "Authentication"** (🔐 no menu lateral)
4. **Clique em "Users"**
5. **Clique em "Add user"** (botão verde no canto superior direito)
6. **Escolha**: "Create new user"
7. **Preencha**:
   - **Email**: seu email (ex: `admin@example.com`)
   - **Password**: sua senha (ex: `senha123`)
   - **Auto Confirm User**: ✅ MARQUE ISSO (importante!)
8. **Clique em**: "Create user"
9. **Pronto!** ✅

### **Depois:**
1. Acesse: http://localhost:5173
2. Faça login com:
   - Email: o que você criou
   - Senha: a que você criou
3. Deve funcionar! 🎉

---

## ✅ SOLUÇÃO 2: Criar Usuário via SQL (Se preferir)

### **Execute no Supabase SQL Editor:**

1. Abra o arquivo: `CRIAR-USUARIO.sql`
2. **ALTERE** as linhas:
   ```sql
   'seu-email@exemplo.com',  -- ALTERAR AQUI
   'sua-senha-123'           -- ALTERAR AQUI
   ```
3. Coloque seu email e senha
4. Execute o script
5. Verifique se o usuário foi criado

---

## 🔍 VERIFICAR USUÁRIOS EXISTENTES

Execute no Supabase SQL Editor:

```sql
SELECT 
    id,
    email,
    created_at,
    last_sign_in_at
FROM auth.users
ORDER BY created_at DESC;
```

Se aparecer vazio = não há usuários cadastrados!

---

## 🎯 USUÁRIO ADMINISTRADOR

Para criar o usuário administrador especial:

**Email**: `adm@bestfybr.com.br`  
**Senha**: a que você escolher

Este usuário tem acesso ao painel de admin.

---

## ⚠️ SE ESQUECEU A SENHA

### **Via Dashboard:**
1. Authentication → Users
2. Clique no usuário
3. Clique em "Reset Password"
4. Defina nova senha

### **Via SQL:**
```sql
UPDATE auth.users
SET encrypted_password = crypt('nova-senha-aqui', gen_salt('bf'))
WHERE email = 'seu-email@exemplo.com';
```

---

## 📝 CREDENCIAIS SUGERIDAS (Para teste)

**Usuário Normal:**
- Email: `usuario@teste.com`
- Senha: `senha123`

**Usuário Admin:**
- Email: `adm@bestfybr.com.br`
- Senha: `admin123`

---

## ✅ CHECKLIST

- [ ] Acessei Supabase Dashboard
- [ ] Fui em Authentication → Users
- [ ] Cliquei em "Add user"
- [ ] Criei usuário com email e senha
- [ ] Marquei "Auto Confirm User"
- [ ] Salvei
- [ ] Voltei para http://localhost:5173
- [ ] Fiz login
- [ ] Funcionou! ✅

---

## 🚨 SE AINDA NÃO FUNCIONAR

1. Verifique se o email está exatamente igual
2. Verifique se a senha está correta
3. Tente criar um novo usuário com email diferente
4. Verifique se "Auto Confirm User" está marcado
5. Me envie o erro completo do console (F12)

---

## 💡 DICA

Depois de criar o usuário, você pode fazer login normalmente.
O sistema lembrará suas credenciais.

