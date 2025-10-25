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

    const authHeader = req.headers.get('Authorization') || '';
    if (!authHeader.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { apiKey } = await req.json();
    if (!apiKey) {
      return new Response(JSON.stringify({ error: 'apiKey é obrigatório' }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Valida a chave na Bestfy do lado do servidor para evitar CORS
    // Suporta tanto chaves do tipo Basic (secret) quanto Bearer (token)
    const tryValidations: Array<Promise<Response>> = [];

    // 1) Basic em bestfybr.com.br (transactions)
    const basicCreds = btoa(`${apiKey}:x`);
    tryValidations.push(fetch('https://api.bestfybr.com.br/v1/transactions?per_page=1', {
      method: 'GET',
      headers: {
        'Authorization': `Basic ${basicCreds}`,
        'Accept': 'application/json',
      },
    }));

    // 2) Bearer em bestfybr.com.br (account)
    tryValidations.push(fetch('https://api.bestfybr.com.br/v1/account', {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Accept': 'application/json',
      },
    }));

    // 3) Bearer em bestfy.com.br (account)
    tryValidations.push(fetch('https://api.bestfy.com.br/v1/account', {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Accept': 'application/json',
      },
    }));

    // 4) Basic em bestfy.com.br (transactions)
    tryValidations.push(fetch('https://api.bestfy.com.br/v1/transactions?per_page=1', {
      method: 'GET',
      headers: {
        'Authorization': `Basic ${basicCreds}`,
        'Accept': 'application/json',
      },
    }));

    let anyOk = false;
    let lastDetails = '';
    for (const p of tryValidations) {
      try {
        const resp = await p;
        if (resp.ok) {
          anyOk = true;
          break;
        } else {
          lastDetails = await resp.text();
        }
      } catch (e) {
        lastDetails = e.message;
      }
    }

    if (!anyOk) {
      return new Response(JSON.stringify({ valid: false, error: 'Chave inválida', details: lastDetails }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ valid: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message || 'Erro interno' }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});


