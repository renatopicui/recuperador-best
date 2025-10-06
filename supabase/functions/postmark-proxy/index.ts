interface PostmarkEmailRequest {
  serverToken: string;
  from: string;
  to: string;
  subject: string;
  htmlBody: string;
  textBody?: string;
  tag?: string;
  metadata?: Record<string, string>;
}

interface PostmarkTestRequest {
  serverToken: string;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

Deno.serve(async (req: Request) => {
  try {
    console.log(`📧 [POSTMARK-PROXY] ${req.method} ${req.url}`);

    // Handle CORS preflight requests
    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 200,
        headers: corsHeaders,
      });
    }

    if (req.method !== "POST") {
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

    const url = new URL(req.url);
    const action = url.pathname.split('/').pop();

    if (!action || !['send-email', 'test-connection'].includes(action)) {
      return new Response(
        JSON.stringify({ error: "Invalid action" }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    const body = await req.json();

    if (action === 'test-connection') {
      const { serverToken } = body as PostmarkTestRequest;

      if (!serverToken) {
        return new Response(
          JSON.stringify({ error: "Server token is required" }),
          {
            status: 400,
            headers: {
              ...corsHeaders,
              "Content-Type": "application/json",
            },
          }
        );
      }

      // Test connection by getting server info
      const response = await fetch('https://api.postmarkapp.com/server', {
        method: 'GET',
        headers: {
          'X-Postmark-Server-Token': serverToken,
          'Accept': 'application/json',
        },
      });

      if (!response.ok) {
        const errorText = await response.text();
        return new Response(
          JSON.stringify({
            success: false,
            message: `Postmark API error: ${response.status} ${response.statusText}`,
            error: errorText
          }),
          {
            status: 200,
            headers: {
              ...corsHeaders,
              "Content-Type": "application/json",
            },
          }
        );
      }

      const serverInfo = await response.json();
      
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Conexão com Postmark estabelecida com sucesso!',
          data: {
            serverName: serverInfo.Name,
            serverId: serverInfo.ID,
            color: serverInfo.Color,
            bounceHookUrl: serverInfo.BounceHookUrl,
            inboundHookUrl: serverInfo.InboundHookUrl
          }
        }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    if (action === 'send-email') {
      const emailData = body as PostmarkEmailRequest;

      if (!emailData.serverToken || !emailData.from || !emailData.to || !emailData.subject || !emailData.htmlBody) {
        return new Response(
          JSON.stringify({ error: "Missing required email fields" }),
          {
            status: 400,
            headers: {
              ...corsHeaders,
              "Content-Type": "application/json",
            },
          }
        );
      }

      // Send email via Postmark API
      const emailPayload = {
        From: emailData.from,
        To: emailData.to,
        Subject: emailData.subject,
        HtmlBody: emailData.htmlBody,
        TextBody: emailData.textBody,
        Tag: emailData.tag,
        Metadata: emailData.metadata
      };

      const response = await fetch('https://api.postmarkapp.com/email', {
        method: 'POST',
        headers: {
          'X-Postmark-Server-Token': emailData.serverToken,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify(emailPayload)
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error(`❌ [POSTMARK-PROXY] Postmark API error ${response.status}:`, errorText);
        return new Response(
          JSON.stringify({
            success: false,
            error: `Postmark API error: ${response.status} ${response.statusText}`,
            details: errorText,
            postmarkError: errorText
          }),
          {
            status: response.status,
            headers: {
              ...corsHeaders,
              "Content-Type": "application/json",
            },
          }
        );
      }

      const result = await response.json();
      
      return new Response(
        JSON.stringify({
          success: true,
          messageId: result.MessageID
        }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    return new Response(
      JSON.stringify({ error: "Unknown action" }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );

  } catch (error) {
    console.error('❌ [POSTMARK-PROXY] Error:', error);
    
    return new Response(
      JSON.stringify({
        success: false,
        error: "Internal server error",
        message: error instanceof Error ? error.message : "Unknown error"
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