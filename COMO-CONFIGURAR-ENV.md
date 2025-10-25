# 🔑 Como Configurar o .env

## ❌ PROBLEMA
```
User not authenticated
```

Este erro acontece porque o arquivo `.env` não existe ou está incorreto.

---

## ✅ SOLUÇÃO (2 minutos)

### **Passo 1: Pegar as credenciais do Supabase**

1. Acesse: https://supabase.com
2. Entre no seu projeto
3. Clique em **"Settings"** (⚙️ no menu lateral)
4. Clique em **"API"**
5. Você verá:
   - **Project URL**: `https://seu-projeto.supabase.co`
   - **anon public key**: `eyJhbGc...` (uma chave bem longa)

### **Passo 2: Criar o arquivo .env**

No VS Code, crie um arquivo chamado `.env` na raiz do projeto:

```
recuperador-best/
├── .env  ← CRIAR ESTE ARQUIVO AQUI
├── src/
├── package.json
└── ...
```

### **Passo 3: Adicionar as variáveis**

Cole isto no arquivo `.env`:

```env
VITE_SUPABASE_URL=https://seu-projeto.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Substitua** pelos valores que você copiou do Supabase!

### **Passo 4: Reiniciar o servidor**

No terminal:

1. Pressione `Ctrl+C` para parar o servidor
2. Execute novamente: `npm run dev`
3. Acesse: http://localhost:5173

---

## 📝 EXEMPLO COMPLETO

```env
VITE_SUPABASE_URL=https://abcdefghijklmnop.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFiY2RlZmdoaWprbG1ub3AiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTY0NzAwMDAwMCwiZXhwIjoxOTYyNTc2MDAwfQ.abc123def456ghi789
```

**ATENÇÃO:** 
- A URL termina com `.supabase.co`
- A chave é MUITO longa (começa com `eyJ...`)
- NÃO tem espaços
- NÃO tem aspas

---

## 🔍 ONDE PEGAR NO SUPABASE

```
Supabase Dashboard
├─ Settings (⚙️)
   └─ API
      ├─ Project URL  ← COPIAR
      └─ anon public  ← COPIAR
```

---

## ✅ VERIFICAR SE FUNCIONOU

Depois de criar o `.env` e reiniciar:

1. Acesse: http://localhost:5173
2. Você deve ver a tela de login
3. Faça login
4. Deve funcionar! ✅

---

## 🚨 SE AINDA NÃO FUNCIONAR

1. Verifique se o arquivo se chama exatamente `.env` (com ponto no início)
2. Verifique se não há espaços nas linhas
3. Verifique se as chaves estão corretas
4. Reinicie o servidor (`Ctrl+C` e `npm run dev` de novo)

---

## 💡 DICA

Nunca compartilhe seu arquivo `.env`!
Ele contém as chaves de acesso ao seu banco de dados.

