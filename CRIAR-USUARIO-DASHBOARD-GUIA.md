# 👤 GUIA: CRIAR USUÁRIO VIA DASHBOARD SUPABASE

## 🎯 OBJETIVO
Criar usuário sem usar o Sign Up do app (que tem bugs)

---

## 📋 PASSO A PASSO COM PRINTS

### **PASSO 1: Acessar Supabase**
```
1. Abra o navegador
2. Vá em: https://supabase.com
3. Faça login na sua conta Supabase
```

### **PASSO 2: Selecionar o Projeto**
```
1. Você verá uma lista de projetos
2. Procure o projeto: daezmxodmvcbmturedcz
3. Clique nele para abrir
```

### **PASSO 3: Ir para Authentication**
```
1. No menu lateral ESQUERDO
2. Procure o ícone 🔐 (cadeado)
3. Nome: "Authentication"
4. Clique nele
```

### **PASSO 4: Abrir Aba Users**
```
1. Na parte SUPERIOR da página
2. Você verá abas: Users | Policies | Providers | etc
3. Clique em "Users"
```

### **PASSO 5: Adicionar Usuário**
```
1. No canto SUPERIOR DIREITO
2. Procure o botão verde "Add user"
3. Clique nele
4. Aparecerá um dropdown
5. Selecione: "Create new user"
```

### **PASSO 6: Preencher Formulário**
```
Um modal/popup abrirá com um formulário:

┌──────────────────────────────────────┐
│ Create a new user                     │
├──────────────────────────────────────┤
│                                       │
│ Email *                               │
│ ┌──────────────────────────────────┐ │
│ │ renato@bestfybr.com.br           │ │ ← Digite aqui
│ └──────────────────────────────────┘ │
│                                       │
│ Password *                            │
│ ┌──────────────────────────────────┐ │
│ │ senha123                         │ │ ← Digite aqui
│ └──────────────────────────────────┘ │
│                                       │
│ ☐ Auto Confirm User                  │ ← MARQUE AQUI!
│                                       │
│ [Cancel] [Create user]                │
└──────────────────────────────────────┘
```

**IMPORTANTE:**
- Email: Use `renato@bestfybr.com.br` ou qualquer email
- Password: Use `senha123` ou qualquer senha (LEMBRE-SE DELA!)
- **MARQUE a caixinha "Auto Confirm User"** ✅

### **PASSO 7: Criar**
```
1. Revise os dados
2. Certifique-se que "Auto Confirm User" está marcado
3. Clique no botão verde "Create user"
4. Aguarde 2-3 segundos
```

### **PASSO 8: Verificar**
```
1. O modal fechará
2. Você voltará para a lista de usuários
3. DEVE aparecer seu usuário na tabela:

┌─────────────────────────────────────────────────────┐
│ Email                    │ Created     │ Last Sign In│
├─────────────────────────────────────────────────────┤
│ renato@bestfybr.com.br  │ Just now    │ Never       │
└─────────────────────────────────────────────────────┘

✅ Se aparecer = Usuário criado com sucesso!
```

---

## 🔐 FAZER LOGIN NO APP

### **PASSO 9: Voltar para o App**
```
1. Abra: http://localhost:5173
2. Você verá a tela de login/cadastro
```

### **PASSO 10: Clicar em "Sign In"**
```
1. Se estiver na tela de cadastro
2. Procure o link "Já tem conta? Entre"
3. Ou procure a aba "Sign In"
4. Clique para ir para a tela de LOGIN
```

### **PASSO 11: Fazer Login**
```
1. Digite:
   - Email: renato@bestfybr.com.br
   - Senha: senha123 (ou a que você criou)

2. Clique em "Entrar" ou "Sign In"

3. Aguarde 2-3 segundos

4. ✅ Você será redirecionado para o Dashboard!
```

---

## ✅ PRONTO!

Se tudo deu certo, você está LOGADO no sistema! 🎉

---

## 🚨 PROBLEMAS COMUNS

### ❌ "Invalid email or password"
- Verifique se o email está EXATAMENTE igual
- Verifique se a senha está correta
- Tente resetar a senha no Supabase Dashboard

### ❌ "Email not confirmed"
- Você esqueceu de marcar "Auto Confirm User"
- Solução: Delete o usuário e crie novamente MARCANDO a opção

### ❌ Não aparece o usuário na lista
- Aguarde alguns segundos e recarregue a página
- Verifique se clicou em "Create user"
- Tente criar novamente

---

## 🔑 CREDENCIAIS CRIADAS

```
Email: renato@bestfybr.com.br
Senha: senha123

OU as que você escolheu!
```

**⚠️ ANOTE SUAS CREDENCIAIS!**

---

## 📸 REFERÊNCIAS VISUAIS

**Caminho no Supabase:**
```
Supabase Dashboard
  └─ Seu Projeto (daezmxodmvcbmturedcz)
      └─ Authentication (🔐 menu esquerdo)
          └─ Users (aba superior)
              └─ Add user (botão verde direita)
                  └─ Create new user
```

**Caminho no App:**
```
http://localhost:5173
  └─ Sign In (login)
      └─ Digite email e senha
          └─ Entrar
              └─ Dashboard! ✅
```

---

## 🎯 RESUMO SUPER RÁPIDO

1. **Supabase.com** → Projeto → Authentication → Users → Add user
2. **Criar**: email + senha + ✅ Auto Confirm
3. **App**: http://localhost:5173 → Sign In → Login
4. **Pronto!** ✅

---

**Siga este guia passo a passo e não terá problemas!** 🚀

