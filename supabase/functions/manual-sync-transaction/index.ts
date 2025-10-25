import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { transactionId, userEmail } = await req.json();
    
    if (!transactionId || !userEmail) {
      return new Response(JSON.stringify({ error: 'transactionId e userEmail são obrigatórios' }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Configuração do Supabase não encontrada');
    }

    // Busca o user_id pelo email
    const userResponse = await fetch(`${supabaseUrl}/rest/v1/auth.users?select=id&email=eq.${encodeURIComponent(userEmail)}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${supabaseServiceKey}`,
        'apikey': supabaseServiceKey,
        'Content-Type': 'application/json',
      }
    });

    if (!userResponse.ok) {
      throw new Error('Usuário não encontrado');
    }

    const users = await userResponse.json();
    if (!users || users.length === 0) {
      throw new Error('Usuário não encontrado');
    }

    const userId = users[0].id;

    // Verifica se a transação já existe
    const existingResponse = await fetch(`${supabaseUrl}/rest/v1/payments?bestfy_id=eq.${transactionId}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${supabaseServiceKey}`,
        'apikey': supabaseServiceKey,
        'Content-Type': 'application/json',
      }
    });

    const existingPayments = await existingResponse.json();

    if (existingPayments && existingPayments.length > 0) {
      // Atualiza o user_id da transação existente
      const updateResponse = await fetch(`${supabaseUrl}/rest/v1/payments?bestfy_id=eq.${transactionId}`, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'apikey': supabaseServiceKey,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: JSON.stringify({
          user_id: userId
        })
      });

      if (updateResponse.ok) {
        return new Response(JSON.stringify({ 
          success: true, 
          message: 'Transação atualizada com sucesso',
          transactionId,
          userId 
        }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      } else {
        throw new Error('Erro ao atualizar transação');
      }
    } else {
      // Cria nova transação
      const createResponse = await fetch(`${supabaseUrl}/rest/v1/payments`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'apikey': supabaseServiceKey,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: JSON.stringify({
          user_id: userId,
          bestfy_id: transactionId,
          customer_name: 'Cliente Sincronizado',
          customer_email: 'cliente@sincronizado.com',
          amount: 10000,
          status: 'paid',
          payment_method: 'pix',
          product_name: 'Produto Sincronizado'
        })
      });

      if (createResponse.ok) {
        return new Response(JSON.stringify({ 
          success: true, 
          message: 'Transação criada com sucesso',
          transactionId,
          userId 
        }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      } else {
        throw new Error('Erro ao criar transação');
      }
    }

  } catch (error) {
    return new Response(JSON.stringify({ 
      error: error.message || 'Erro interno',
      transactionId: req.body?.transactionId 
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
