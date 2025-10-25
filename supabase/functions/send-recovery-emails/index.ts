const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

interface PaymentRecord {
  id: string;
  bestfy_id: string;
  customer_email: string;
  customer_name: string;
  product_name: string;
  amount: number;
  status: string;
  payment_method?: string;
  created_at: string;
  recovery_email_sent_at?: string;
}

interface CheckoutLinkRecord {
  checkout_slug: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    console.log(`📧 [RECOVERY-EMAILS] Iniciando verificação de emails de recuperação`);

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const postmarkToken = Deno.env.get('POSTMARK_SERVER_TOKEN') || '444cb041-a2de-4ece-b066-e345a0f5d8bd';

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Variáveis de ambiente não configuradas');
    }

    // Busca pagamentos pendentes que ainda não receberam email
    // Vamos verificar o tempo configurado por cada usuário
    const paymentsResponse = await fetch(
      `${supabaseUrl}/rest/v1/payments?status=eq.waiting_payment&payment_method=eq.pix&recovery_email_sent_at=is.null&select=*,checkout_links(checkout_slug),user_id`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'apikey': supabaseServiceKey,
          'Content-Type': 'application/json',
        }
      }
    );

    if (!paymentsResponse.ok) {
      throw new Error(`Erro ao buscar pagamentos: ${paymentsResponse.status}`);
    }

    const paymentsRaw: (PaymentRecord & { checkout_links: CheckoutLinkRecord[], user_id?: string })[] = await paymentsResponse.json();

    // Filtra apenas pagamentos que têm checkout link
    const paymentsWithCheckout = paymentsRaw.filter(p => p.checkout_links && p.checkout_links.length > 0);
    
    console.log(`📋 [RECOVERY-EMAILS] Encontrados ${paymentsWithCheckout.length} pagamentos com checkout`);

    // Buscar configurações de todos os usuários
    const userIds = [...new Set(paymentsWithCheckout.map(p => p.user_id).filter(Boolean))];
    const userSettingsMap = new Map<string, number>();

    // Buscar configurações de cada usuário
    for (const userId of userIds) {
      try {
        const settingsResponse = await fetch(
          `${supabaseUrl}/rest/v1/user_settings?user_id=eq.${userId}&select=recovery_email_delay_minutes`,
          {
            method: 'GET',
            headers: {
              'Authorization': `Bearer ${supabaseServiceKey}`,
              'apikey': supabaseServiceKey,
              'Content-Type': 'application/json',
            }
          }
        );

        if (settingsResponse.ok) {
          const settings = await settingsResponse.json();
          if (settings && settings.length > 0) {
            userSettingsMap.set(userId, settings[0].recovery_email_delay_minutes);
            console.log(`⚙️ [RECOVERY-EMAILS] Usuário ${userId}: ${settings[0].recovery_email_delay_minutes} minutos`);
          }
        }
      } catch (e) {
        console.warn(`⚠️ [RECOVERY-EMAILS] Erro ao buscar configuração do usuário ${userId}:`, e);
      }
    }

    // Filtrar pagamentos que já atingiram o tempo configurado
    const payments = paymentsWithCheckout.filter(p => {
      const delayMinutes = p.user_id ? (userSettingsMap.get(p.user_id) || 3) : 3;
      const createdAt = new Date(p.created_at);
      const now = new Date();
      const minutesSinceCreation = (now.getTime() - createdAt.getTime()) / (1000 * 60);
      
      const shouldSend = minutesSinceCreation >= delayMinutes;
      
      if (!shouldSend) {
        console.log(`⏳ [RECOVERY-EMAILS] Pagamento ${p.bestfy_id}: ${Math.floor(minutesSinceCreation)}/${delayMinutes} min - aguardando`);
      }
      
      return shouldSend;
    });
    
    console.log(`📤 [RECOVERY-EMAILS] ${payments.length} pagamentos prontos para envio`);

    const results = [];

    for (const payment of payments) {
      try {
        console.log(`📤 [RECOVERY-EMAILS] Enviando email para: ${payment.customer_email} (${payment.bestfy_id})`);

        // Constrói URL do nosso checkout
        const checkoutSlug = payment.checkout_links[0]?.checkout_slug;
        if (!checkoutSlug) {
          console.log(`⚠️ [RECOVERY-EMAILS] Pagamento ${payment.bestfy_id} sem checkout slug, pulando`);
          continue;
        }

        const checkoutUrl = `https://onabetbr.live/checkout/${checkoutSlug}`;
        console.log(`🔗 [RECOVERY-EMAILS] Checkout URL: ${checkoutUrl}`);

        // Envia email via Postmark
        const emailResponse = await fetch('https://api.postmarkapp.com/email', {
          method: 'POST',
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-Postmark-Server-Token': postmarkToken
          },
          body: JSON.stringify({
            From: 'Bestfy Pay <noreply@onabetbr.live>',
            To: payment.customer_email,
            Subject: `🔔 ${payment.customer_name}, finalize seu PIX - ${payment.product_name}`,
            HtmlBody: `
              <!DOCTYPE html>
              <html>
              <head>
                <meta charset="utf-8">
                <title>Complete seu Pagamento PIX</title>
                <style>
                  body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                  .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                  .header { background: #32BCAD; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
                  .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
                  .urgent { background: #32BCAD; color: white; padding: 15px; border-radius: 6px; margin: 20px 0; text-align: center; }
                  .details { background: white; padding: 20px; border-radius: 6px; margin: 20px 0; }
                  .cta-button { 
                    display: inline-block; 
                    background: #32BCAD; 
                    color: white; 
                    padding: 15px 30px; 
                    text-decoration: none; 
                    border-radius: 6px; 
                    font-weight: bold; 
                    margin: 20px 0;
                    font-size: 18px;
                  }
                  .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
                </style>
              </head>
              <body>
                <div class="container">
                  <div class="header">
                    <h1>🔔 Seu PIX está esperando!</h1>
                  </div>
                  <div class="content">
                    <div class="urgent">
                      <h2>⏰ Seu pagamento PIX está pendente</h2>
                    </div>
                    
                    <p>Olá <strong>${payment.customer_name}</strong>,</p>
                    
                    <p>Você iniciou um pagamento via <strong>PIX</strong> mas ainda não finalizou. O PIX é instantâneo e sua compra será liberada imediatamente!</p>
                    
                    <div class="details">
                      <h3>📦 Detalhes da sua Compra</h3>
                      <p><strong>Produto:</strong> ${payment.product_name}</p>
                      <p><strong>Valor:</strong> R$ ${(payment.amount / 100).toFixed(2).replace('.', ',')}</p>
                      <p><strong>Método:</strong> PIX (Pagamento Instantâneo)</p>
                      <p><strong>ID:</strong> ${payment.bestfy_id}</p>
                    </div>
                    
                    <div style="text-align: center;">
                      <p><strong>⚡ Finalize seu PIX agora e receba seu produto instantaneamente!</strong></p>
                      <a href="${checkoutUrl}" class="cta-button">📱 Pagar com PIX Agora</a>
                    </div>
                    
                    <div class="footer">
                      <p>Este e-mail foi enviado porque você iniciou um pagamento PIX.</p>
                    </div>
                  </div>
                </div>
              </body>
              </html>
            `,
            TextBody: `Olá ${payment.customer_name}, finalize seu PIX de R$ ${(payment.amount / 100).toFixed(2).replace('.', ',')}. Acesse: ${checkoutUrl}`,
            Tag: 'pix-recovery',
            TrackOpens: true,
            Metadata: {
              transaction_id: payment.bestfy_id,
              customer_name: payment.customer_name,
              checkout_slug: checkoutSlug,
              checkout_url: checkoutUrl
            }
          })
        });

        if (!emailResponse.ok) {
          const errorText = await emailResponse.text();
          console.error(`❌ [RECOVERY-EMAILS] Erro ao enviar email:`, errorText);
          results.push({
            bestfy_id: payment.bestfy_id,
            email: payment.customer_email,
            success: false,
            error: errorText
          });
          continue;
        }

        const emailResult = await emailResponse.json();
        console.log(`✅ [RECOVERY-EMAILS] Email enviado: MessageID ${emailResult.MessageID}`);

        // Atualiza o registro para marcar que o email foi enviado
        await fetch(
          `${supabaseUrl}/rest/v1/payments?id=eq.${payment.id}`,
          {
            method: 'PATCH',
            headers: {
              'Authorization': `Bearer ${supabaseServiceKey}`,
              'apikey': supabaseServiceKey,
              'Content-Type': 'application/json',
              'Prefer': 'return=representation'
            },
            body: JSON.stringify({
              recovery_email_sent_at: new Date().toISOString()
            })
          }
        );

        results.push({
          bestfy_id: payment.bestfy_id,
          email: payment.customer_email,
          success: true,
          messageId: emailResult.MessageID
        });

      } catch (error) {
        console.error(`❌ [RECOVERY-EMAILS] Erro ao processar ${payment.bestfy_id}:`, error);
        results.push({
          bestfy_id: payment.bestfy_id,
          email: payment.customer_email,
          success: false,
          error: error instanceof Error ? error.message : 'Erro desconhecido'
        });
      }
    }

    const successCount = results.filter(r => r.success).length;
    const failureCount = results.filter(r => !r.success).length;

    console.log(`✅ [RECOVERY-EMAILS] Concluído: ${successCount} enviados, ${failureCount} falharam`);

    return new Response(
      JSON.stringify({
        success: true,
        message: `Processados ${payments.length} pagamentos`,
        stats: {
          total: payments.length,
          sent: successCount,
          failed: failureCount
        },
        results
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    );

  } catch (error) {
    console.error(`❌ [RECOVERY-EMAILS] Erro geral:`, error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Erro desconhecido'
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    );
  }
});