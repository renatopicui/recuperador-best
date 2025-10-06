// Edge Function para executar sincronização via Cron Job
// Esta função pode ser chamada por serviços como GitHub Actions, Vercel Cron, etc.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

Deno.serve(async (req: Request) => {
  try {
    console.log(`⏰ [CRON] Executando sincronização automática via Cron Job`);

    // Handle CORS preflight requests
    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 200,
        headers: corsHeaders,
      });
    }

    // Só aceita POST para execução do cron
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ 
          error: "Method not allowed",
          message: "Use POST para executar sincronização"
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

    // Verifica se tem token de autorização (opcional, para segurança)
    const authHeader = req.headers.get('Authorization');
    const cronSecret = Deno.env.get('CRON_SECRET');
    
    if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
      console.log(`🔒 [CRON] Token de autorização inválido ou ausente`);
      return new Response(
        JSON.stringify({ 
          error: "Unauthorized",
          message: "Token de autorização inválido"
        }),
        {
          status: 401,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    // Chama a função de sincronização
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    if (!supabaseUrl) {
      throw new Error('SUPABASE_URL não configurada');
    }

    const syncUrl = `${supabaseUrl}/functions/v1/bestfy-sync`;
    console.log(`🔄 [CRON] Chamando função de sincronização: ${syncUrl}`);

    const syncResponse = await fetch(syncUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
      }
    });

    if (!syncResponse.ok) {
      const errorText = await syncResponse.text();
      throw new Error(`Erro na sincronização: ${syncResponse.status} - ${errorText}`);
    }

    const syncResult = await syncResponse.json();

    console.log(`✅ [CRON] Sincronização concluída:`, syncResult.stats);

    // Envia emails de recuperação
    const recoveryEmailsUrl = `${supabaseUrl}/functions/v1/send-recovery-emails`;
    console.log(`📧 [CRON] Verificando emails de recuperação: ${recoveryEmailsUrl}`);

    const recoveryResponse = await fetch(recoveryEmailsUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
      }
    });

    let recoveryResult = { success: false, stats: { total: 0, sent: 0, failed: 0 } };
    if (recoveryResponse.ok) {
      recoveryResult = await recoveryResponse.json();
      console.log(`✅ [CRON] Recovery emails processados:`, recoveryResult.stats);
    } else {
      const errorText = await recoveryResponse.text();
      console.error(`❌ [CRON] Erro ao processar recovery emails: ${errorText}`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Sincronização automática executada com sucesso",
        cron_execution: {
          timestamp: new Date().toISOString(),
          triggered_by: "cron_job"
        },
        sync_result: syncResult,
        recovery_emails: recoveryResult
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );

  } catch (error) {
    console.error(`❌ [CRON] Erro na execução do cron job:`, error);
    
    return new Response(
      JSON.stringify({
        success: false,
        error: "Cron job execution failed",
        message: error instanceof Error ? error.message : "Unknown error",
        timestamp: new Date().toISOString()
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