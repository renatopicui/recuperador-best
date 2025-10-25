interface BestfyWebhookPayload {
  id: number;
  type: string;
  objectId: string;
  url: string;
  data: {
    id: number;
    amount: number;
    refundedAmount: number;
    companyId: number;
    installments: number;
    paymentMethod: string;
    status: string;
    postbackUrl?: string;
    metadata?: any;
    traceable: boolean;
    secureId: string;
    secureUrl: string;
    createdAt: string;
    updatedAt: string;
    paidAt?: string;
    ip?: string;
    externalRef?: string;
    customer: {
      id: number;
      externalRef?: string;
      name: string;
      email: string;
      phone?: string;
      birthdate?: string;
      createdAt: string;
      document?: {
        number: string;
        type: string;
      };
      address?: {
        street: string;
        streetNumber: string;
        complement?: string;
        zipCode: string;
        neighborhood: string;
        city: string;
        state: string;
        country: string;
      };
    };
    card?: {
      id: number;
      brand: string;
      holderName: string;
      lastDigits: string;
      expirationMonth: number;
      expirationYear: number;
      reusable: boolean;
      createdAt: string;
    };
    boleto?: any;
    pix?: any;
    shipping?: any;
    refusedReason?: string;
    items: Array<{
      externalRef?: string;
      title: string;
      unitPrice: number;
      quantity: number;
      tangible: boolean;
    }>;
    splits?: Array<{
      recipientId: number;
      amount: number;
      netAmount: number;
    }>;
    refunds?: any[];
    delivery?: any;
    fee?: {
      fixedAmount: number;
      spreadPercentage: number;
      estimatedFee: number;
      netAmount: number;
    };
  };
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Requested-With",
};

Deno.serve(async (req: Request) => {
  const startTime = Date.now();
  const requestId = Math.random().toString(36).substring(7);

  try {
    console.log(`🔔 [${requestId}] Webhook recebido: ${req.method} ${req.url}`);
    console.log(`📋 [${requestId}] Headers recebidos:`, Object.fromEntries(req.headers.entries()));
    console.log(`⏰ [${requestId}] Timestamp: ${new Date().toISOString()}`);

    if (req.method === "OPTIONS") {
      console.log(`✅ [${requestId}] Respondendo a requisição OPTIONS (CORS)`);
      return new Response(null, {
        status: 200,
        headers: corsHeaders,
      });
    }

    if (req.method === "GET") {
      console.log(`ℹ️ [${requestId}] Requisição GET - testando webhook e banco`);

      const supabaseUrl = Deno.env.get('SUPABASE_URL');
      const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

      let dbStatus = "❌ Erro";
      if (supabaseUrl && supabaseServiceKey) {
        try {
          const testResponse = await fetch(`${supabaseUrl}/rest/v1/payments?select=id&limit=1`, {
            method: 'GET',
            headers: {
              'Authorization': `Bearer ${supabaseServiceKey}`,
              'Content-Type': 'application/json',
              'apikey': supabaseServiceKey
            }
          });
          if (testResponse.ok) {
            const data = await testResponse.json();
            dbStatus = `✅ Conectado (${data.length} registros)`;
          } else {
            const errorText = await testResponse.text();
            dbStatus = `❌ Erro ${testResponse.status}: ${errorText}`;
          }
        } catch (error) {
          dbStatus = `❌ Erro: ${error.message}`;
        }
      }

      return new Response(
        JSON.stringify({
          message: "🚀 Webhook da Bestfy está funcionando!",
          timestamp: new Date().toISOString(),
          url: req.url,
          method: req.method,
          requestId: requestId,
          database_status: dbStatus,
          environment: {
            supabase_url: supabaseUrl ? "✅ Configurado" : "❌ Não encontrado",
            service_key: supabaseServiceKey ? "✅ Configurado" : "❌ Não encontrado"
          },
          instructions: {
            "1": "Configure este URL como webhook na Bestfy",
            "2": "Eventos recomendados: transaction.created, transaction.updated, transaction.paid, transaction.refused, transaction.cancelled",
            "3": "Método: POST",
            "4": "Content-Type: application/json"
          }
        }, null, 2),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    if (req.method !== "POST") {
      console.log(`❌ [${requestId}] Método ${req.method} não permitido`);
      return new Response(
        JSON.stringify({
          error: "Method not allowed",
          allowed_methods: ["GET", "POST", "OPTIONS"],
          requestId: requestId
        }),
        {
          status: 405,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    console.log(`🔔 [${requestId}] Processando webhook POST da Bestfy`);

    const body = await req.text();
    console.log(`📦 [${requestId}] Body recebido (${body.length} chars):`, body);

    if (!body || body.trim() === '') {
      console.log(`❌ [${requestId}] Body vazio recebido`);
      return new Response(
        JSON.stringify({
          error: "Empty body",
          requestId: requestId,
          received_length: body.length
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    let payload: BestfyWebhookPayload;
    try {
      payload = JSON.parse(body);
      console.log(`📦 [${requestId}] Payload parseado com sucesso`);
    } catch (parseError) {
      console.error(`❌ [${requestId}] Erro ao fazer parse do JSON:`, parseError);
      return new Response(
        JSON.stringify({
          error: "Invalid JSON",
          parseError: parseError.message,
          body_preview: body.substring(0, 500),
          requestId: requestId
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    const transactionId = payload.data?.id || payload.objectId || payload.id;

    if (!transactionId) {
      console.error(`❌ [${requestId}] ID da transação não encontrado no payload`);
      return new Response(
        JSON.stringify({
          error: "Transaction ID is required",
          available_fields: Object.keys(payload),
          data_fields: payload.data ? Object.keys(payload.data) : null,
          requestId: requestId
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    const webhookData = payload.data;
    const customer = webhookData?.customer || {};
    const items = webhookData?.items || [];

    console.log(`📋 [${requestId}] Dados extraídos da Bestfy:`, {
      transactionId,
      type: payload.type,
      status: webhookData?.status,
      amount: webhookData?.amount,
      paymentMethod: webhookData?.paymentMethod,
      customer: customer.name,
      items_count: items.length,
    });

    const paymentRecord = {
      bestfy_id: transactionId.toString(),
      customer_name: customer.name || 'Cliente não informado',
      customer_email: customer.email || 'email@nao-informado.com',
      customer_phone: customer.phone || '',
      customer_document: customer.document?.number || null,
      product_name: items[0]?.title || 'Produto não especificado',
      amount: webhookData?.amount || 0,
      currency: 'BRL',
      status: webhookData?.status || 'waiting_payment',
      payment_method: webhookData?.paymentMethod,
      secure_url: webhookData?.secureUrl,
      updated_at: new Date().toISOString()
    };

    console.log(`💾 [${requestId}] Salvando no banco:`, {
      bestfy_id: paymentRecord.bestfy_id,
      status: paymentRecord.status,
      amount: paymentRecord.amount,
      customer: paymentRecord.customer_name
    });

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error(`❌ [${requestId}] Variáveis de ambiente do Supabase não encontradas`);
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

    console.log(`🔗 [${requestId}] Salvando no Supabase usando UPSERT`);

    const checkResponse = await fetch(
      `${supabaseUrl}/rest/v1/payments?bestfy_id=eq.${paymentRecord.bestfy_id}&select=id,bestfy_id,user_id,recovery_source,recovery_checkout_link_id`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'apikey': supabaseServiceKey,
          'Content-Type': 'application/json',
        }
      }
    );

    const existingRecords = await checkResponse.json();
    const exists = Array.isArray(existingRecords) && existingRecords.length > 0;
    const existingUserId = exists ? existingRecords[0].user_id : null;
    const existingRecoverySource = exists ? existingRecords[0].recovery_source : null;
    const existingRecoveryCheckoutLinkId = exists ? existingRecords[0].recovery_checkout_link_id : null;

    console.log(`🔍 [${requestId}] Registro existente:`, exists ? `Sim, atualizando (user_id: ${existingUserId})` : 'Não, inserindo');

    let supabaseResponse;
    let responseText;

    if (exists) {
      const updatePayload: any = {
        ...paymentRecord,
        user_id: existingUserId,
        recovery_source: existingRecoverySource,
        recovery_checkout_link_id: existingRecoveryCheckoutLinkId
      };

      if (paymentRecord.status === 'paid' && 
          (existingRecoverySource === 'recovery_checkout' || existingRecoveryCheckoutLinkId)) {
        updatePayload.converted_from_recovery = true;
        console.log(`🎯 [${requestId}] *** VENDA RECUPERADA DETECTADA ***`);
        console.log(`🎯 [${requestId}] Bestfy ID: ${paymentRecord.bestfy_id}`);
        console.log(`🎯 [${requestId}] Status: ${paymentRecord.status}`);
        console.log(`🎯 [${requestId}] Recovery Source: ${existingRecoverySource}`);
        console.log(`🎯 [${requestId}] Checkout Link ID: ${existingRecoveryCheckoutLinkId}`);
        console.log(`🎯 [${requestId}] MARCANDO COMO CONVERTED_FROM_RECOVERY = TRUE`);
      }

      supabaseResponse = await fetch(
        `${supabaseUrl}/rest/v1/payments?bestfy_id=eq.${paymentRecord.bestfy_id}`,
        {
          method: 'PATCH',
          headers: {
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'apikey': supabaseServiceKey,
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: JSON.stringify(updatePayload)
        }
      );
    } else {
      // MÉTODO PRINCIPAL: Resolve usuário pelo company_id do webhook
      let resolvedUserId: string | null = null;
      const webhookCompanyId = webhookData?.companyId;
      
      console.log(`🔍 [${requestId}] ========== DEBUG RESOLUÇÃO USUÁRIO ==========`);
      console.log(`🔍 [${requestId}] Company ID do webhook: ${JSON.stringify(webhookCompanyId)}`);
      console.log(`🔍 [${requestId}] Tipo do Company ID: ${typeof webhookCompanyId}`);
      console.log(`🔍 [${requestId}] Transaction ID: ${paymentRecord.bestfy_id}`);
      
      if (webhookCompanyId) {
        console.log(`🏢 [${requestId}] Buscando usuário pelo company_id: ${webhookCompanyId}`);
        
        try {
          const queryUrl = `${supabaseUrl}/rest/v1/api_keys?select=user_id,bestfy_company_id,is_active,service&is_active=eq.true&service=eq.bestfy&bestfy_company_id=eq.${webhookCompanyId}`;
          console.log(`🔍 [${requestId}] URL da query: ${queryUrl}`);
          
          const companyIdResponse = await fetch(queryUrl, {
            method: 'GET',
            headers: {
              'Authorization': `Bearer ${supabaseServiceKey}`,
              'apikey': supabaseServiceKey,
              'Content-Type': 'application/json',
            }
          });

          console.log(`📊 [${requestId}] Status da resposta: ${companyIdResponse.status}`);

          if (companyIdResponse.ok) {
            const matchingKeys = await companyIdResponse.json();
            console.log(`📊 [${requestId}] Registros encontrados: ${JSON.stringify(matchingKeys, null, 2)}`);
            console.log(`📊 [${requestId}] Quantidade de registros: ${matchingKeys.length}`);
            
            if (Array.isArray(matchingKeys) && matchingKeys.length > 0) {
              resolvedUserId = matchingKeys[0].user_id;
              console.log(`✅ [${requestId}] *** SUCESSO: Usuário encontrado ***`);
              console.log(`✅ [${requestId}] user_id: ${resolvedUserId}`);
              console.log(`✅ [${requestId}] bestfy_company_id: ${matchingKeys[0].bestfy_company_id}`);
            } else {
              console.error(`❌ [${requestId}] Array VAZIO - nenhum registro encontrado`);
              console.error(`❌ [${requestId}] Company ID procurado: ${webhookCompanyId}`);
              console.error(`❌ [${requestId}] AÇÃO: Verificar se existe registro com bestfy_company_id = '${webhookCompanyId}'`);
            }
          } else {
            const errorText = await companyIdResponse.text();
            console.error(`❌ [${requestId}] Erro HTTP: ${companyIdResponse.status}`);
            console.error(`❌ [${requestId}] Erro body: ${errorText}`);
          }
        } catch (companyIdErr) {
          console.error(`❌ [${requestId}] EXCEÇÃO ao buscar:`, companyIdErr);
        }
      } else {
        console.error(`❌ [${requestId}] webhookCompanyId é NULL/undefined`);
        console.error(`❌ [${requestId}] Payload completo: ${JSON.stringify(webhookData, null, 2)}`);
      }
      
      console.log(`🔍 [${requestId}] resolvedUserId FINAL: ${resolvedUserId}`);

      // FALLBACK: Se não resolveu por company_id, tenta por email do cliente
      if (!resolvedUserId) {
        console.log(`🔄 [${requestId}] Tentando fallback por email...`);
        
        if (paymentRecord.customer_email) {
          try {
            const email = encodeURIComponent(paymentRecord.customer_email);
            const byEmailResp = await fetch(
              `${supabaseUrl}/rest/v1/payments?select=user_id,customer_email,created_at&customer_email=eq.${email}&order=created_at.desc&limit=1`,
              {
                method: 'GET',
                headers: {
                  'Authorization': `Bearer ${supabaseServiceKey}`,
                  'apikey': supabaseServiceKey,
                  'Content-Type': 'application/json',
                }
              }
            );

            if (byEmailResp.ok) {
              const rows = await byEmailResp.json();
              if (Array.isArray(rows) && rows.length > 0) {
                resolvedUserId = rows[0].user_id;
                console.log(`📧 [${requestId}] Dono inferido por email (${paymentRecord.customer_email}): ${resolvedUserId}`);
              }
            }
          } catch (e) {
            console.warn(`⚠️ [${requestId}] Erro no fallback por email:`, e);
          }
        }
      }

      const userIdToAssign = resolvedUserId || (exists ? existingUserId : null);
      if (!userIdToAssign) {
        console.warn(`⚠️ [${requestId}] Não foi possível identificar o usuário dono; tentando fallback por email`);
        
        // Fallback final: busca por email do cliente em transações existentes
        if (paymentRecord.customer_email) {
          try {
            const email = encodeURIComponent(paymentRecord.customer_email);
            const byEmailResp = await fetch(
              `${supabaseUrl}/rest/v1/payments?select=user_id,customer_email,created_at&customer_email=eq.${email}&order=created_at.desc&limit=1`,
              {
                method: 'GET',
                headers: {
                  'Authorization': `Bearer ${supabaseServiceKey}`,
                  'apikey': supabaseServiceKey,
                  'Content-Type': 'application/json',
                }
              }
            );

            if (byEmailResp.ok) {
              const rows = await byEmailResp.json();
              if (Array.isArray(rows) && rows.length > 0) {
                const fallbackUserId = rows[0].user_id;
                console.log(`📧 [${requestId}] Usuário encontrado por email: ${fallbackUserId}`);
                resolvedUserId = fallbackUserId;
              }
            }
          } catch (e) {
            console.warn(`⚠️ [${requestId}] Erro no fallback por email:`, e);
          }
        }

        // Se ainda não resolveu, NÃO cria a transação
        if (!resolvedUserId) {
          console.error(`❌ [${requestId}] ERRO: Não foi possível identificar o usuário dono da transação`);
          console.error(`❌ [${requestId}] Transaction ID: ${paymentRecord.bestfy_id}`);
          console.error(`❌ [${requestId}] Company ID do webhook: ${webhookCompanyId}`);
          console.error(`❌ [${requestId}] Customer Email: ${paymentRecord.customer_email}`);
          
          return new Response(JSON.stringify({
            error: 'Owner user not resolved for transaction',
            transaction_id: paymentRecord.bestfy_id,
            company_id: webhookCompanyId,
            customer_email: paymentRecord.customer_email,
            message: 'Usuário não possui chave API cadastrada ou bestfy_company_id não foi salvo corretamente',
            requestId: requestId
          }), { 
            status: 400, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          });
        }
      }

      supabaseResponse = await fetch(`${supabaseUrl}/rest/v1/payments`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'apikey': supabaseServiceKey,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: JSON.stringify({
          ...paymentRecord,
          user_id: resolvedUserId
        })
      });

      console.log(`👤 [${requestId}] Novo payment criado com user_id: ${resolvedUserId}`);
    }

    responseText = await supabaseResponse.text();

    if (!supabaseResponse.ok) {
      console.error(`❌ [${requestId}] Erro ao salvar no Supabase:`, {
        status: supabaseResponse.status,
        body: responseText
      });

      return new Response(
        JSON.stringify({
          error: "Failed to save payment",
          supabase_error: responseText,
          supabase_status: supabaseResponse.status,
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

    let savedPayment;
    try {
      savedPayment = responseText ? JSON.parse(responseText) : null;
    } catch (e) {
      savedPayment = responseText;
    }

    console.log(`✅ [${requestId}] Pagamento salvo/atualizado com sucesso`);

    console.log(`🔄 [${requestId}] Forçando sincronização de checkout para bestfy_id: ${paymentRecord.bestfy_id}`);
    
    try {
      const checkoutUpdateResponse = await fetch(
        `${supabaseUrl}/rest/v1/checkout_links?payment_bestfy_id=eq.${paymentRecord.bestfy_id}`,
        {
          method: 'PATCH',
          headers: {
            'Authorization': `Bearer ${supabaseServiceKey}`,
            'apikey': supabaseServiceKey,
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: JSON.stringify({
            payment_status: paymentRecord.status,
            last_status_check: new Date().toISOString()
          })
        }
      );

      if (checkoutUpdateResponse.ok) {
        const updatedCheckouts = await checkoutUpdateResponse.json();
        console.log(`✅ [${requestId}] Atualizados ${updatedCheckouts.length} checkout links para status: ${paymentRecord.status}`);
        
        updatedCheckouts.forEach((checkout: any) => {
          console.log(`🔗 [${requestId}] Checkout atualizado: ${checkout.checkout_slug} -> ${paymentRecord.status}`);
        });
      } else {
        const errorText = await checkoutUpdateResponse.text();
        console.error(`❌ [${requestId}] Falha ao atualizar checkout status: ${errorText}`);
      }
    } catch (checkoutError) {
      console.error(`❌ [${requestId}] Erro ao atualizar checkout status:`, checkoutError);
    }

    const processingTime = Date.now() - startTime;

    const successResponse = {
      success: true,
      message: "Webhook processed successfully",
      transaction_id: transactionId,
      event_type: payload.type,
      status: webhookData?.status,
      saved_at: new Date().toISOString(),
      processing_time_ms: processingTime,
      requestId: requestId
    };

    console.log(`✅ [${requestId}] Enviando resposta de sucesso (${processingTime}ms)`);

    return new Response(
      JSON.stringify(successResponse),
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
    console.error(`❌ [${requestId}] Erro geral no webhook (${processingTime}ms):`, error);
    console.error(`🔍 [${requestId}] Stack trace:`, error instanceof Error ? error.stack : 'No stack trace');

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