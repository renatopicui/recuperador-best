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
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Configuração do Supabase não encontrada');
    }

    // Busca todas as transações que não têm user_id correto
    const orphanedResponse = await fetch(`${supabaseUrl}/rest/v1/payments?select=id,bestfy_id,customer_email,user_id&user_id=eq.1fa3b630-a6ad-411f-8891-da15ed5eb00d`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${supabaseServiceKey}`,
        'apikey': supabaseServiceKey,
        'Content-Type': 'application/json',
      }
    });

    if (!orphanedResponse.ok) {
      throw new Error('Erro ao buscar transações órfãs');
    }

    const orphanedTransactions = await orphanedResponse.json();
    console.log(`🔍 Encontradas ${orphanedTransactions.length} transações órfãs`);

    let syncedCount = 0;
    const results = [];

    for (const transaction of orphanedTransactions) {
      try {
        // Tenta encontrar o usuário correto por email
        if (transaction.customer_email) {
          const userResponse = await fetch(`${supabaseUrl}/rest/v1/payments?select=user_id&customer_email=eq.${encodeURIComponent(transaction.customer_email)}&user_id=neq.1fa3b630-a6ad-411f-8891-da15ed5eb00d&limit=1`, {
            method: 'GET',
            headers: {
              'Authorization': `Bearer ${supabaseServiceKey}`,
              'apikey': supabaseServiceKey,
              'Content-Type': 'application/json',
            }
          });

          if (userResponse.ok) {
            const matchingPayments = await userResponse.json();
            if (matchingPayments && matchingPayments.length > 0) {
              const correctUserId = matchingPayments[0].user_id;
              
              // Atualiza a transação com o user_id correto
              const updateResponse = await fetch(`${supabaseUrl}/rest/v1/payments?id=eq.${transaction.id}`, {
                method: 'PATCH',
                headers: {
                  'Authorization': `Bearer ${supabaseServiceKey}`,
                  'apikey': supabaseServiceKey,
                  'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                  user_id: correctUserId
                })
              });

              if (updateResponse.ok) {
                syncedCount++;
                results.push({
                  transactionId: transaction.bestfy_id,
                  oldUserId: transaction.user_id,
                  newUserId: correctUserId,
                  status: 'success'
                });
                console.log(`✅ Transação ${transaction.bestfy_id} sincronizada com usuário ${correctUserId}`);
              } else {
                results.push({
                  transactionId: transaction.bestfy_id,
                  status: 'error',
                  error: 'Falha ao atualizar'
                });
              }
            }
          }
        }
      } catch (error) {
        results.push({
          transactionId: transaction.bestfy_id,
          status: 'error',
          error: error.message
        });
      }
    }

    return new Response(JSON.stringify({
      success: true,
      message: `Sincronização concluída: ${syncedCount} transações processadas`,
      totalOrphaned: orphanedTransactions.length,
      syncedCount,
      results
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    return new Response(JSON.stringify({
      error: error.message || 'Erro interno'
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
