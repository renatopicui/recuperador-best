interface BestfyTransaction {
  id: number;
  amount: number;
  status: string;
  paymentMethod: string;
  secureUrl?: string;
  createdAt: string;
  updatedAt: string;
  customer?: {
    name: string;
    email: string;
    phone?: string;
    document?: {
      number: string;
      type: string;
    };
  };
  product?: {
    name: string;
    title?: string;
  };
  items?: Array<{
    title: string;
    unitPrice: number;
    quantity: number;
  }>;
}

interface PaymentRecord {
  bestfy_id: string;
  customer_name: string;
  customer_email: string;
  customer_phone?: string;
  customer_document?: string;
  product_name: string;
  amount: number;
  currency: string;
  status: string;
  payment_method?: string;
  secure_url?: string;
  source: string;
  updated_at: string;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

Deno.serve(async (req: Request) => {
  const startTime = Date.now();
  const requestId = Math.random().toString(36).substring(7);
  
  try {
    console.log(`🔄 [SYNC-${requestId}] Iniciando sincronização automática da Bestfy`);

    // Handle CORS preflight requests
    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 200,
        headers: corsHeaders,
      });
    }

    // Só aceita GET e POST
    if (!['GET', 'POST'].includes(req.method)) {
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        {
          status: 405,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    // Inicializa Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error(`❌ [SYNC-${requestId}] Variáveis de ambiente do Supabase não encontradas`);
      return new Response(
        JSON.stringify({ 
          error: "Supabase configuration missing",
          requestId: requestId
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    console.log(`🔗 [SYNC-${requestId}] Conectando ao Supabase: ${supabaseUrl}`);

    // Busca todas as chaves API ativas dos usuários
    const apiKeysResponse = await fetch(`${supabaseUrl}/rest/v1/api_keys?select=*,user_id&is_active=eq.true&service=eq.bestfy`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${supabaseServiceKey}`,
        'Content-Type': 'application/json',
        'apikey': supabaseServiceKey
      }
    });

    if (!apiKeysResponse.ok) {
      const errorText = await apiKeysResponse.text();
      console.error(`❌ [SYNC-${requestId}] Erro ao buscar chaves API:`, errorText);
      return new Response(
        JSON.stringify({ 
          error: "Failed to fetch API keys",
          details: errorText,
          requestId: requestId
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    const apiKeys = await apiKeysResponse.json();
    console.log(`🔑 [SYNC-${requestId}] Encontradas ${apiKeys.length} chaves API ativas`);

    let totalSynced = 0;
    let totalErrors = 0;
    const syncResults = [];

    // Para cada usuário com chave API ativa
    for (const apiKeyRecord of apiKeys) {
      try {
        console.log(`👤 [SYNC-${requestId}] Sincronizando usuário: ${apiKeyRecord.user_id}`);
        
        // Descriptografa a chave API (Base64)
        const decryptedKey = atob(apiKeyRecord.encrypted_key);
        
        // Busca transações da API Bestfy
        const bestfyTransactions = await fetchBestfyTransactions(decryptedKey, requestId);
        console.log(`📦 [SYNC-${requestId}] API Bestfy retornou ${bestfyTransactions.length} transações para usuário ${apiKeyRecord.user_id}`);
        
        if (bestfyTransactions.length === 0) {
          syncResults.push({
            user_id: apiKeyRecord.user_id,
            synced: 0,
            error: null,
            message: 'Nenhuma transação encontrada na API'
          });
          continue;
        }

        // Busca transações já salvas no banco para este usuário
        const existingResponse = await fetch(`${supabaseUrl}/rest/v1/payments?select=bestfy_id&user_id=eq.${apiKeyRecord.user_id}`, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'Content-Type': 'application/json',
            'apikey': supabaseServiceKey
          }
        });

        const existingPayments = existingResponse.ok ? await existingResponse.json() : [];
        const existingIds = new Set(existingPayments.map((p: any) => p.bestfy_id));
        console.log(`💾 [SYNC-${requestId}] Usuário ${apiKeyRecord.user_id} tem ${existingPayments.length} transações salvas`);

        // Filtra apenas transações novas ou atualizadas
        const transactionsToSync = bestfyTransactions.filter(transaction => {
          return !existingIds.has(transaction.id.toString());
        });

        console.log(`🆕 [SYNC-${requestId}] ${transactionsToSync.length} novas transações para sincronizar`);

        if (transactionsToSync.length === 0) {
          syncResults.push({
            user_id: apiKeyRecord.user_id,
            synced: 0,
            error: null,
            message: 'Todas as transações já estão sincronizadas'
          });
          continue;
        }

        // Converte para formato do banco
        const paymentRecords: PaymentRecord[] = transactionsToSync.map(transaction => ({
          bestfy_id: transaction.id.toString(),
          customer_name: transaction.customer?.name || 'Cliente não informado',
          customer_email: transaction.customer?.email || 'email@nao-informado.com',
          customer_phone: transaction.customer?.phone || '',
          customer_document: transaction.customer?.document?.number || null,
          product_name: transaction.items?.[0]?.title || transaction.product?.title || transaction.product?.name || 'Produto não especificado',
          amount: transaction.amount,
          currency: 'BRL',
          status: transaction.status || 'waiting_payment',
          payment_method: transaction.paymentMethod,
          secure_url: transaction.secureUrl,
          source: 'backend_sync',
          updated_at: new Date().toISOString()
        }));

        // Salva no banco com user_id
        const paymentsWithUserId = paymentRecords.map(payment => ({
          ...payment,
          user_id: apiKeyRecord.user_id
        }));

        const saveResponse = await fetch(`${supabaseUrl}/rest/v1/payments`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'apikey': supabaseServiceKey,
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates,return=representation',
            'Prefer-Count': 'exact'
          },
          body: JSON.stringify(paymentsWithUserId.map(payment => ({
            ...payment,
            // Ensure we're using the composite key for conflict resolution
            on_conflict: 'bestfy_id,user_id'
          })))
        });

        if (!saveResponse.ok) {
          const errorText = await saveResponse.text();
          console.error(`❌ [SYNC-${requestId}] Erro ao salvar transações para usuário ${apiKeyRecord.user_id}:`, errorText);
          totalErrors++;
          syncResults.push({
            user_id: apiKeyRecord.user_id,
            synced: 0,
            error: errorText,
            message: 'Erro ao salvar no banco de dados'
          });
          continue;
        }

        const savedPayments = await saveResponse.json();
        console.log(`✅ [SYNC-${requestId}] ${savedPayments.length} transações salvas para usuário ${apiKeyRecord.user_id}`);
        
        totalSynced += savedPayments.length;
        syncResults.push({
          user_id: apiKeyRecord.user_id,
          synced: savedPayments.length,
          error: null,
          message: `${savedPayments.length} transações sincronizadas com sucesso`
        });

      } catch (error) {
        console.error(`❌ [SYNC-${requestId}] Erro ao sincronizar usuário ${apiKeyRecord.user_id}:`, error);
        totalErrors++;
        syncResults.push({
          user_id: apiKeyRecord.user_id,
          synced: 0,
          error: error instanceof Error ? error.message : 'Erro desconhecido',
          message: 'Erro durante sincronização'
        });
      }
    }

    const processingTime = Date.now() - startTime;
    const result = {
      success: true,
      message: `Sincronização concluída em ${processingTime}ms`,
      stats: {
        users_processed: apiKeys.length,
        total_synced: totalSynced,
        total_errors: totalErrors,
        processing_time_ms: processingTime
      },
      results: syncResults,
      timestamp: new Date().toISOString(),
      requestId: requestId
    };

    console.log(`✅ [SYNC-${requestId}] Sincronização concluída:`, result.stats);

    return new Response(
      JSON.stringify(result),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );

  } catch (error) {
    const processingTime = Date.now() - startTime;
    console.error(`❌ [SYNC-${requestId}] Erro geral na sincronização (${processingTime}ms):`, error);
    
    return new Response(
      JSON.stringify({
        success: false,
        error: "Internal server error",
        message: error instanceof Error ? error.message : "Unknown error",
        timestamp: new Date().toISOString(),
        processing_time_ms: processingTime,
        requestId: requestId
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});

async function fetchBestfyTransactions(secretKey: string, requestId: string): Promise<BestfyTransaction[]> {
  try {
    console.log(`🌐 [SYNC-${requestId}] Buscando transações da API Bestfy...`);
    
    // Rate limiting
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    const credentials = btoa(`${secretKey}:x`);
    const response = await fetch('https://api.bestfybr.com.br/v1/transactions', {
      method: 'GET',
      headers: {
        'Authorization': `Basic ${credentials}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    });

    if (!response.ok) {
      if (response.status === 401) {
        throw new Error('Chave secreta inválida ou não autorizada');
      }
      if (response.status === 403) {
        throw new Error('Acesso negado. Verifique suas permissões');
      }
      if (response.status === 429) {
        throw new Error('Rate limit excedido');
      }
      throw new Error(`Erro HTTP ${response.status}: ${response.statusText}`);
    }

    const contentType = response.headers.get('content-type');
    if (!contentType || !contentType.includes('application/json')) {
      throw new Error('Resposta da API não é JSON válido');
    }

    const data = await response.json();
    
    // Verifica se a resposta é um array direto ou objeto com propriedade data
    let transactions: BestfyTransaction[] = [];
    
    if (Array.isArray(data)) {
      transactions = data;
    } else if (data && typeof data === 'object') {
      if (data.success !== undefined && !data.success) {
        throw new Error(data.message || 'API retornou erro');
      }
      transactions = data.data || [];
    }
    
    console.log(`📦 [SYNC-${requestId}] API retornou ${transactions.length} transações`);
    return transactions;
    
  } catch (error) {
    console.error(`❌ [SYNC-${requestId}] Erro ao buscar da API Bestfy:`, error);
    throw error;
  }
}