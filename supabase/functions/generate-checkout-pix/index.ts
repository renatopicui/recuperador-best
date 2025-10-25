import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const { checkout_id } = await req.json();

    if (!checkout_id) {
      return new Response(
        JSON.stringify({ error: "checkout_id é obrigatório" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Configuração do Supabase não encontrada');
    }

    console.log('Buscando checkout:', checkout_id);
    const checkoutResponse = await fetch(
      `${supabaseUrl}/rest/v1/checkout_links?id=eq.${checkout_id}&select=*`,
      {
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'apikey': supabaseServiceKey,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!checkoutResponse.ok) {
      throw new Error('Erro ao buscar checkout');
    }

    const checkouts = await checkoutResponse.json();
    if (!checkouts || checkouts.length === 0) {
      return new Response(
        JSON.stringify({ error: "Checkout não encontrado" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const checkout = checkouts[0];
    console.log('Checkout encontrado:', checkout.checkout_slug);

    const apiKeyResponse = await fetch(
      `${supabaseUrl}/rest/v1/rpc/get_api_key_for_user`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'apikey': supabaseServiceKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ user_uuid: checkout.user_id }),
      }
    );

    if (!apiKeyResponse.ok) {
      const errorText = await apiKeyResponse.text();
      console.error('Erro ao buscar API key:', errorText);
      throw new Error('Erro ao buscar API key');
    }

    const apiKeyEncoded = await apiKeyResponse.json();

    if (!apiKeyEncoded) {
      return new Response(
        JSON.stringify({ error: "API Key não configurada" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log('API Key encontrada (encoded)');    const apiKey = atob(apiKeyEncoded);
    const credentials = btoa(`${apiKey}:x`);

    const paymentResponse = await fetch(
      `${supabaseUrl}/rest/v1/payments?id=eq.${checkout.payment_id}&select=bestfy_id`,
      {
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'apikey': supabaseServiceKey,
          'Content-Type': 'application/json',
        },
      }
    );

    let originalTransaction = null;
    if (paymentResponse.ok) {
      const payments = await paymentResponse.json();
      if (payments && payments.length > 0 && payments[0].bestfy_id) {
        console.log('Buscando transação original da Bestfy:', payments[0].bestfy_id);

        const bestfyGetResponse = await fetch(
          `https://api.bestfybr.com.br/v1/transactions/${payments[0].bestfy_id}`,
          {
            headers: {
              'Authorization': `Basic ${credentials}`,
              'Accept': 'application/json',
            },
          }
        );

        if (bestfyGetResponse.ok) {
          originalTransaction = await bestfyGetResponse.json();
          console.log('Transação original encontrada com customer:', originalTransaction.customer);
        }
      }
    }

    // Os valores no banco JÁ estão em centavos, não multiplicar!
    const amountInCents = Math.round(Number(checkout.final_amount || checkout.amount));

    let customerPayload;
    if (originalTransaction?.customer) {
      customerPayload = {
        name: originalTransaction.customer.name,
        email: originalTransaction.customer.email,
        ...(originalTransaction.customer.phone && { phone: originalTransaction.customer.phone }),
        ...(originalTransaction.customer.document && { document: originalTransaction.customer.document }),
      };
      console.log('Usando dados do customer original da Bestfy');
    } else {
      const documentNumber = checkout.customer_document?.replace(/\D/g, '') || '';
      const documentType = documentNumber.length === 11 ? 'cpf' : 'cnpj';
      customerPayload = {
        name: checkout.customer_name,
        email: checkout.customer_email,
        ...(documentNumber && {
          document: {
            number: documentNumber,
            type: documentType
          }
        }),
      };
      console.log('Usando dados do checkout');
    }

    const payload = {
      amount: amountInCents,
      customer: customerPayload,
      items: [{
        title: checkout.product_name,
        quantity: 1,
        unitPrice: amountInCents,
        tangible: false,
      }],
      paymentMethod: 'pix',
    };

    console.log('Criando cobrança na Bestfy com payload:', JSON.stringify(payload));

    const bestfyResponse = await fetch('https://api.bestfybr.com.br/v1/transactions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': `Basic ${credentials}`,
      },
      body: JSON.stringify(payload),
    });

    console.log('Status Bestfy:', bestfyResponse.status);
    const responseText = await bestfyResponse.text();
    console.log('Resposta Bestfy:', responseText);

    if (!bestfyResponse.ok) {
      return new Response(
        JSON.stringify({
          error: "Erro ao gerar PIX na Bestfy",
          status: bestfyResponse.status,
          details: responseText
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const bestfyData = JSON.parse(responseText);
    console.log('🎯 Bestfy Data completo:', JSON.stringify(bestfyData, null, 2));
    console.log('🎯 PIX object:', bestfyData.pix);
    
    // ✅ BESTFY USA "qrcode" (MINÚSCULO)!
    const qrCode = bestfyData.pix?.qrcode  // ← ESTE É O CAMPO CORRETO!
      || bestfyData.pix?.qrCode 
      || bestfyData.pix?.qr_code 
      || bestfyData.pix?.QrCode
      || bestfyData.pix?.emvqrcps
      || bestfyData.pix?.pixCopiaECola
      || bestfyData.qrCode
      || bestfyData.qr_code
      || null;
    
    console.log('🎫 QR Code extraído:', qrCode ? `${qrCode.substring(0, 50)}...` : 'NULL');
    
    if (!qrCode) {
      console.error('❌ ATENÇÃO: QR Code não encontrado na resposta da Bestfy!');
      console.error('❌ Campos disponíveis no pix:', Object.keys(bestfyData.pix || {}));
    }

    const updateData = {
      payment_bestfy_id: bestfyData.id?.toString(),
      payment_status: bestfyData.status,
      pix_qrcode: qrCode,
      pix_expires_at: bestfyData.pix?.expiresAt || bestfyData.pix?.expires_at || bestfyData.pix?.expirationDate || null,
      pix_generated_at: new Date().toISOString(),
    };

    console.log('💾 Update data para salvar no banco:', JSON.stringify(updateData, null, 2));

    console.log('🔄 Atualizando checkout no banco...');
    
    const updateResponse = await fetch(
      `${supabaseUrl}/rest/v1/checkout_links?id=eq.${checkout_id}`,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'apikey': supabaseServiceKey,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: JSON.stringify(updateData),
      }
    );

    console.log('📡 Status do update:', updateResponse.status);

    if (!updateResponse.ok) {
      const errorText = await updateResponse.text();
      console.error('❌ Erro ao atualizar checkout:', errorText);
      throw new Error('Erro ao salvar dados do PIX');
    }

    const updatedCheckout = await updateResponse.json();
    console.log('✅ Checkout atualizado com sucesso!');
    console.log('✅ Dados atualizados:', JSON.stringify(updatedCheckout[0], null, 2));

    // 🎯 VINCULAR PAYMENT AO CHECKOUT PARA RASTREAMENTO DE RECUPERAÇÃO
    console.log('🔗 Vinculando payment ao checkout para rastreamento de recuperação...');
    
    const paymentUpdateResponse = await fetch(
      `${supabaseUrl}/rest/v1/payments?id=eq.${checkout.payment_id}`,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'apikey': supabaseServiceKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          recovery_source: 'recovery_checkout',
          recovery_checkout_link_id: checkout_id,
          bestfy_id: bestfyData.id?.toString()  // Atualiza com o novo bestfy_id do checkout
        }),
      }
    );

    if (paymentUpdateResponse.ok) {
      console.log('✅ Payment vinculado ao checkout! Quando pago, será marcado como RECUPERADO.');
    } else {
      console.warn('⚠️ Não foi possível vincular payment ao checkout:', await paymentUpdateResponse.text());
    }

    return new Response(
      JSON.stringify({ success: true, data: updatedCheckout[0] }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error('Erro:', error);
    return new Response(
      JSON.stringify({ error: error.message || "Erro interno" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});