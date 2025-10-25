-- ===================================================================
-- 📧 FORÇAR ENVIO DE EMAIL DE RECUPERAÇÃO MANUALMENTE
-- ===================================================================
-- Use este script para enviar email AGORA, sem esperar cron job
-- Email: renatopicui1@gmail.com
-- ===================================================================

-- IMPORTANTE: Execute primeiro DIAGNOSTICAR-EMAIL-NAO-ENVIADO.sql
-- para garantir que:
-- 1. Postmark está configurado
-- 2. Pagamento está com status 'waiting_payment'
-- 3. Email ainda não foi enviado

-- ===================================================================
-- OPÇÃO 1: CHAMAR EDGE FUNCTION (Recomendado)
-- ===================================================================

-- Copie e cole este comando no terminal (substitua SEU-PROJETO):
-- curl -X POST https://SEU-PROJETO.supabase.co/functions/v1/send-recovery-emails

-- Ou execute via SQL (se pg_net estiver configurado):
-- SELECT net.http_post(
--     url := 'https://SEU-PROJETO.supabase.co/functions/v1/send-recovery-emails'
-- );

-- ===================================================================
-- OPÇÃO 2: EXECUTAR LÓGICA DIRETAMENTE NO BANCO (Emergência)
-- ===================================================================

DO $$
DECLARE
    v_payment RECORD;
    v_checkout RECORD;
    v_email_settings RECORD;
    v_app_url TEXT;
    v_email_body TEXT;
    v_email_subject TEXT;
BEGIN
    -- Buscar configuração de APP_URL
    SELECT value INTO v_app_url 
    FROM system_settings 
    WHERE key = 'APP_URL';
    
    IF v_app_url IS NULL THEN
        v_app_url := 'http://localhost:5173';
    END IF;
    
    RAISE NOTICE '📍 APP_URL: %', v_app_url;
    
    -- Buscar o pagamento
    SELECT * INTO v_payment
    FROM payments
    WHERE customer_email = 'renatopicui1@gmail.com'
    AND status = 'waiting_payment'
    AND recovery_email_sent_at IS NULL
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF v_payment.id IS NULL THEN
        RAISE EXCEPTION '❌ Pagamento não encontrado ou já teve email enviado';
    END IF;
    
    RAISE NOTICE '📋 Payment encontrado: %', v_payment.id;
    
    -- Buscar email_settings do usuário
    SELECT * INTO v_email_settings
    FROM email_settings
    WHERE user_id = v_payment.user_id
    AND is_active = TRUE;
    
    IF v_email_settings.id IS NULL THEN
        RAISE EXCEPTION '❌ Email settings não configurado para este usuário!';
    END IF;
    
    RAISE NOTICE '✅ Email settings encontrado';
    
    -- Verificar se já existe checkout link
    SELECT * INTO v_checkout
    FROM checkout_links
    WHERE payment_id = v_payment.id;
    
    -- Se não existe, criar checkout link
    IF v_checkout.id IS NULL THEN
        RAISE NOTICE '🔗 Criando checkout link...';
        
        INSERT INTO checkout_links (
            payment_id,
            user_id,
            checkout_slug,
            customer_name,
            customer_email,
            customer_document,
            customer_address,
            product_name,
            amount,
            original_amount,
            discount_percentage,
            discount_amount,
            final_amount,
            payment_bestfy_id,
            expires_at
        )
        VALUES (
            v_payment.id,
            v_payment.user_id,
            generate_checkout_slug(),
            v_payment.customer_name,
            v_payment.customer_email,
            v_payment.customer_document,
            v_payment.customer_address,
            v_payment.product_name,
            v_payment.amount,
            v_payment.amount,
            20.00,
            ROUND(v_payment.amount * 0.20, 0),
            v_payment.amount - ROUND(v_payment.amount * 0.20, 0),
            v_payment.bestfy_id,
            NOW() + INTERVAL '24 hours'
        )
        RETURNING * INTO v_checkout;
        
        RAISE NOTICE '✅ Checkout criado: %', v_checkout.checkout_slug;
    ELSE
        RAISE NOTICE '✅ Checkout já existe: %', v_checkout.checkout_slug;
    END IF;
    
    -- Preparar corpo do email
    v_email_subject := 'Complete seu Pagamento PIX - 20% de Desconto!';
    
    v_email_body := format('
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { text-align: center; padding: 20px 0; }
                .discount-badge { 
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 15px 30px;
                    border-radius: 10px;
                    display: inline-block;
                    font-size: 20px;
                    font-weight: bold;
                    margin: 20px 0;
                }
                .pricing { 
                    background: #f7fafc;
                    border-radius: 10px;
                    padding: 20px;
                    margin: 20px 0;
                }
                .original-price { 
                    text-decoration: line-through;
                    color: #999;
                    font-size: 18px;
                }
                .final-price { 
                    font-size: 32px;
                    color: #10b981;
                    font-weight: bold;
                    margin: 10px 0;
                }
                .savings { 
                    color: #10b981;
                    font-size: 16px;
                }
                .button { 
                    display: inline-block;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 15px 40px;
                    text-decoration: none;
                    border-radius: 8px;
                    font-size: 18px;
                    font-weight: bold;
                    margin: 20px 0;
                }
                .footer { 
                    text-align: center;
                    color: #999;
                    font-size: 14px;
                    margin-top: 40px;
                    padding-top: 20px;
                    border-top: 1px solid #eee;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🎉 Oferta Especial para Você!</h1>
                </div>
                
                <div class="discount-badge">
                    20%% DE DESCONTO EXCLUSIVO
                </div>
                
                <p>Olá, <strong>%s</strong>!</p>
                
                <p>Notamos que você iniciou um pagamento mas ainda não finalizou.</p>
                
                <p><strong>Preparamos um desconto especial de 20%% só para você!</strong></p>
                
                <div class="pricing">
                    <p class="original-price">De: R$ %s</p>
                    <p class="final-price">Por: R$ %s</p>
                    <p class="savings">Você economiza R$ %s</p>
                </div>
                
                <p><strong>Produto:</strong> %s</p>
                
                <div style="text-align: center; margin: 30px 0;">
                    <a href="%s/checkout/%s" class="button">
                        Aproveitar Desconto e Pagar Agora
                    </a>
                </div>
                
                <p><small>⏰ Este link e desconto expiram em 24 horas.</small></p>
                
                <div class="footer">
                    <p>Se você já pagou, ignore este email.</p>
                    <p>Se tiver alguma dúvida, responda este email.</p>
                </div>
            </div>
        </body>
        </html>
    ',
        v_payment.customer_name,
        (v_checkout.amount / 100.0)::numeric(10,2),
        (v_checkout.final_amount / 100.0)::numeric(10,2),
        (v_checkout.discount_amount / 100.0)::numeric(10,2),
        v_payment.product_name,
        v_app_url,
        v_checkout.checkout_slug
    );
    
    RAISE NOTICE '📧 Email preparado';
    RAISE NOTICE 'Para: %', v_payment.customer_email;
    RAISE NOTICE 'De: %', v_email_settings.from_email;
    RAISE NOTICE 'Link: %/checkout/%', v_app_url, v_checkout.checkout_slug;
    
    -- ATENÇÃO: Este script NÃO envia o email automaticamente
    -- Você precisa chamar a Edge Function do Postmark
    -- Ou usar o comando curl abaixo
    
    -- Marcar como enviado (apenas se você realmente enviar)
    -- UPDATE payments 
    -- SET recovery_email_sent_at = NOW()
    -- WHERE id = v_payment.id;
    
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'PRÓXIMO PASSO: Enviar email via Postmark';
    RAISE NOTICE '=================================================================';
    RAISE NOTICE 'Opção 1: Chamar edge function send-recovery-emails';
    RAISE NOTICE 'Opção 2: Usar Postmark API diretamente';
    RAISE NOTICE '';
    RAISE NOTICE 'Dados do email:';
    RAISE NOTICE 'To: %', v_payment.customer_email;
    RAISE NOTICE 'From: %', v_email_settings.from_email;
    RAISE NOTICE 'Subject: %', v_email_subject;
    RAISE NOTICE 'Checkout URL: %/checkout/%', v_app_url, v_checkout.checkout_slug;
    
END $$;

-- ===================================================================
-- ✅ VERIFICAR SE CHECKOUT FOI CRIADO
-- ===================================================================

SELECT 
    '✅ VERIFICAÇÃO' as tipo,
    checkout_slug,
    'http://localhost:5173/checkout/' || checkout_slug as link_completo,
    final_amount,
    discount_amount,
    expires_at,
    CASE 
        WHEN expires_at > NOW() THEN '✅ Válido'
        ELSE '❌ Expirado'
    END as status
FROM checkout_links
WHERE payment_id IN (
    SELECT id FROM payments 
    WHERE customer_email = 'renatopicui1@gmail.com'
)
ORDER BY created_at DESC
LIMIT 1;

-- ===================================================================
-- IMPORTANTE:
-- ===================================================================
-- Este script cria o checkout link mas NÃO envia o email
-- 
-- Para enviar o email, você precisa:
-- 1. Chamar a Edge Function: send-recovery-emails
-- 2. Ou enviar manualmente via Postmark Dashboard
-- 3. Ou usar curl com Postmark API
--
-- Após enviar, execute:
-- UPDATE payments 
-- SET recovery_email_sent_at = NOW()
-- WHERE customer_email = 'renatopicui1@gmail.com';
-- ===================================================================

