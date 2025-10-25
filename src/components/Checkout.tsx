import { useEffect, useState } from 'react';
import { checkoutService } from '../services/checkoutService';
import { recoveryService } from '../services/recoveryService';
import { supabase } from '../services/supabaseService';
import { CheckoutLink } from '../types/bestfy';
import { CheckCircle2, Clock, XCircle, Copy, Check, Loader2, Timer, Package, ChevronDown, ChevronUp, Lock, CreditCard } from 'lucide-react';
import QRCode from 'qrcode';

export default function Checkout() {
  const [checkout, setCheckout] = useState<CheckoutLink | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [qrCodeImage, setQrCodeImage] = useState('');
  const [copied, setCopied] = useState(false);
  const [generatingPix, setGeneratingPix] = useState(false);
  const [timeRemaining, setTimeRemaining] = useState<number>(0);
  const [fixedTimer, setFixedTimer] = useState<number>(15 * 60 * 1000); // 15 minutos em ms
  const [isProductDetailsOpen, setIsProductDetailsOpen] = useState(true);

  useEffect(() => {
    loadCheckout();
  }, []);

  useEffect(() => {
    if (checkout?.payment_status === 'waiting_payment') {
      const interval = setInterval(() => {
        checkPaymentStatus();
      }, 5000);
      return () => clearInterval(interval);
    }
  }, [checkout]);

  useEffect(() => {
    if (checkout?.expires_at) {
      const updateTimer = () => {
        const now = new Date().getTime();
        const expiry = new Date(checkout.expires_at).getTime();
        const remaining = Math.max(0, expiry - now);
        setTimeRemaining(remaining);

        if (remaining === 0) {
          setError('Este link de checkout expirou');
        }
      };

      updateTimer();
      const interval = setInterval(updateTimer, 1000);
      return () => clearInterval(interval);
    }
  }, [checkout?.expires_at]);

  // Timer fixo de 15 minutos que sempre diminui
  useEffect(() => {
    const interval = setInterval(() => {
      setFixedTimer((prev) => {
        const newTime = prev - 1000;
        return newTime > 0 ? newTime : 0;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, []);

  const loadCheckout = async () => {
    try {
      const path = window.location.pathname;
      const slug = path.split('/checkout/')[1];

      console.log('📥 [loadCheckout] Carregando checkout com slug:', slug);

      if (!slug) {
        setError('Link inválido');
        setLoading(false);
        return;
      }

      const data = await checkoutService.getCheckoutBySlug(slug);

      console.log('📥 [loadCheckout] Dados recebidos do banco:', {
        slug: data?.checkout_slug,
        amount: data?.amount,
        final_amount: data?.final_amount,
        has_qrcode: !!data?.pix_qrcode,
        payment_status: data?.payment_status
      });

      if (!data) {
        setError('Checkout não encontrado');
        setLoading(false);
        return;
      }

      setCheckout(data);
      console.log('✅ [loadCheckout] Checkout atualizado no state');

      if (data.pix_qrcode) {
        console.log('🎫 [loadCheckout] QR Code encontrado! Gerando imagem...');
        const qrImage = await QRCode.toDataURL(data.pix_qrcode);
        setQrCodeImage(qrImage);
        setIsProductDetailsOpen(false);
        console.log('✅ [loadCheckout] QR Code gerado com sucesso!');
      } else {
        console.log('⏳ [loadCheckout] Ainda não há QR Code');
      }
    } catch (err: any) {
      console.error('❌ [loadCheckout] Erro:', err);
      setError(err.message || 'Erro ao carregar checkout');
    } finally {
      setLoading(false);
    }
  };

  const checkPaymentStatus = async () => {
    if (!checkout) return;

    try {
      const data = await checkoutService.getCheckoutBySlug(checkout.checkout_slug);
      if (data && data.payment_status !== checkout.payment_status) {
        // Se o pagamento foi confirmado, redirecionar para página de obrigado
        if (data.payment_status === 'paid' && checkout.payment_status !== 'paid') {
          console.log('🎉 Pagamento confirmado! Redirecionando para página de obrigado...');
          
          // Redirecionar para página de obrigado com o thank_you_slug
          if (data.thank_you_slug) {
            console.log('✅ Redirecionando para:', `/obrigado/${data.thank_you_slug}`);
            window.location.href = `/obrigado/${data.thank_you_slug}`;
            return; // Não continuar processamento
          } else {
            console.warn('⚠️ thank_you_slug não encontrado, usando comportamento antigo');
          }
        }
        
        setCheckout(data);
        if (data.pix_qrcode) {
          const qrImage = await QRCode.toDataURL(data.pix_qrcode);
          setQrCodeImage(qrImage);
        }
      }
    } catch (err) {
      console.error('Erro ao verificar status:', err);
    }
  };

  const handleGeneratePix = async () => {
    if (!checkout) return;

    console.log('🚀 [Checkout] Iniciando geração de PIX...');
    console.log('🚀 [Checkout] Checkout ID:', checkout.id);
    console.log('🚀 [Checkout] Valor final:', checkout.final_amount, 'centavos (R$', checkout.final_amount / 100, ')');

    setGeneratingPix(true);
    setError('');
    try {
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

      console.log('📡 [Checkout] Chamando Edge Function...');

      const response = await fetch(`${supabaseUrl}/functions/v1/generate-checkout-pix`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${supabaseAnonKey}`,
        },
        body: JSON.stringify({
          checkout_id: checkout.id,
        }),
      });

      console.log('📡 [Checkout] Status da resposta:', response.status);

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        console.error('❌ [Checkout] Erro na resposta:', errorData);
        throw new Error(errorData.error || 'Erro ao gerar PIX');
      }

      const result = await response.json();
      console.log('✅ [Checkout] Resposta da Edge Function:', result);

      if (!result.success) {
        throw new Error(result.error || 'Erro ao gerar PIX');
      }

      console.log('🔄 [Checkout] Recarregando checkout...');
      await loadCheckout();
      
      console.log('✅ [Checkout] PIX gerado com sucesso! Fechando detalhes do produto...');
      setIsProductDetailsOpen(false);
    } catch (err: any) {
      console.error('❌ [Checkout] Erro ao gerar PIX:', err);
      setError(err.message || 'Erro ao gerar PIX');
    } finally {
      setGeneratingPix(false);
      console.log('🏁 [Checkout] Processo finalizado');
    }
  };

  const handleCopyPix = async () => {
    if (checkout?.pix_qrcode) {
      await navigator.clipboard.writeText(checkout.pix_qrcode);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const formatCurrency = (value: number) => {
    // Valores no banco estão em centavos, então dividimos por 100
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL',
    }).format(value / 100);
  };

  const formatTime = (milliseconds: number) => {
    const minutes = Math.floor(milliseconds / 60000);
    const seconds = Math.floor((milliseconds % 60000) / 1000);
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  };

  const getStatusConfig = (status: string) => {
    const configs: Record<string, { icon: any; color: string; text: string }> = {
      paid: { icon: CheckCircle2, color: 'text-green-400', text: 'Pagamento Confirmado!' },
      waiting_payment: { icon: Clock, color: 'text-yellow-400', text: 'Aguardando Pagamento' },
      expired: { icon: XCircle, color: 'text-red-400', text: 'Expirado' },
      cancelled: { icon: XCircle, color: 'text-red-400', text: 'Cancelado' },
    };
    return configs[status] || configs.waiting_payment;
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 flex items-center justify-center">
        <div className="text-white text-xl">Carregando checkout...</div>
      </div>
    );
  }

  if (error || !checkout) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 flex items-center justify-center p-4">
        <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-2xl p-8 max-w-md w-full text-center">
          <XCircle className="w-16 h-16 text-red-500 mx-auto mb-4" />
          <h2 className="text-2xl font-bold text-white mb-2">Erro</h2>
          <p className="text-gray-400">{error || 'Checkout não encontrado'}</p>
        </div>
      </div>
    );
  }

  const statusConfig = getStatusConfig(checkout.payment_status);
  const StatusIcon = statusConfig.icon;
  const hasDiscount = checkout.discount_percentage && checkout.discount_percentage > 0;

  // Se o pagamento já está pago, redirecionar para página de obrigado
  if (checkout.payment_status === 'paid' && checkout.thank_you_slug) {
    window.location.href = `/obrigado/${checkout.thank_you_slug}`;
    return (
      <div className="min-h-screen bg-white flex items-center justify-center">
        <div className="text-center">
          <Loader2 className="w-12 h-12 text-blue-600 animate-spin mx-auto mb-4" />
          <p className="text-gray-600">Redirecionando...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-white p-4 py-12">
      <div className="max-w-2xl mx-auto">
        {!checkout.pix_qrcode && (
          <>
            {hasDiscount && (
              <div className="bg-gradient-to-r from-green-500 to-emerald-600 text-white rounded-xl p-4 mb-4 shadow-lg">
                <div className="flex items-center justify-center gap-2 mb-1">
                  <CheckCircle2 className="w-5 h-5" />
                  <h2 className="text-lg font-bold">Parabéns!</h2>
                </div>
                <p className="text-center text-sm font-semibold">
                  Você ganhou {checkout.discount_percentage}% de desconto!
                </p>
              </div>
            )}

            <div className="bg-white/80 backdrop-blur-lg rounded-2xl shadow-xl overflow-hidden border border-gray-100">
              <div className="bg-gradient-to-r from-blue-600 to-blue-700 text-white p-6 text-center">
                <div className={`flex items-center justify-center gap-2 mb-2 ${checkout.payment_status === 'paid' ? 'text-green-300' : ''}`}>
                  <StatusIcon className="w-5 h-5" />
                  <span className="text-sm font-medium">{statusConfig.text}</span>
                </div>
                <h1 className="text-xl font-bold mb-3">Finalize seu Pedido</h1>

                <div className="flex items-center justify-center gap-6 text-sm">
                  {fixedTimer > 0 && (
                    <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-orange-500 border border-orange-400">
                      <Timer className="w-4 h-4" />
                      <span className="font-semibold">{formatTime(fixedTimer)}</span>
                    </div>
                  )}
                  <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-gray-500/80 border border-gray-400">
                    <Package className="w-4 h-4" />
                    <span className="font-semibold">Disponível: 1</span>
                  </div>
                </div>
              </div>

              <div className="p-6">
                <div className="mb-6">
                  <button
                    onClick={() => setIsProductDetailsOpen(!isProductDetailsOpen)}
                    className="w-full flex items-center justify-between text-lg font-bold text-gray-800 mb-4 pb-3 border-b border-gray-200 hover:text-blue-600 transition-colors"
                  >
                    <span>Resumo do Pedido</span>
                    {isProductDetailsOpen ? (
                      <ChevronUp className="w-5 h-5" />
                    ) : (
                      <ChevronDown className="w-5 h-5" />
                    )}
                  </button>

                  {isProductDetailsOpen && (
                    <div className="space-y-4 mb-6">
                      <div className="bg-gradient-to-br from-gray-50 to-gray-100 rounded-xl p-4">
                        <h3 className="text-base font-bold text-gray-800 mb-3">{checkout.product_name}</h3>

                        <div className="space-y-2">
                          {hasDiscount && checkout.original_amount && (
                            <div className="flex justify-between items-center">
                              <span className="text-sm text-gray-600">Preço original:</span>
                              <span className="text-sm text-gray-500 line-through">{formatCurrency(Number(checkout.original_amount))}</span>
                            </div>
                          )}
                          {hasDiscount && checkout.discount_amount && (
                            <div className="flex justify-between items-center">
                              <span className="text-sm text-gray-600">Desconto aplicado:</span>
                              <span className="text-sm text-green-600 font-semibold">-{formatCurrency(Number(checkout.discount_amount))}</span>
                            </div>
                          )}
                          <div className="flex justify-between items-center pt-3 border-t border-gray-300">
                            <span className="text-gray-800 font-bold">Total a pagar:</span>
                            <span className="text-2xl font-bold text-blue-600">
                              {formatCurrency(Number(checkout.final_amount || checkout.amount))}
                            </span>
                          </div>
                        </div>
                      </div>

                      <div className={`grid ${checkout.customer_address ? 'md:grid-cols-2' : 'md:grid-cols-1'} gap-3`}>
                        <div className="bg-blue-50 rounded-lg p-4 border border-blue-100">
                          <h4 className="font-semibold text-gray-700 mb-2 text-xs uppercase tracking-wide">Dados do Cliente</h4>
                          <div className="space-y-2 text-sm">
                            <div>
                              <p className="text-gray-500 text-xs">Nome</p>
                              <p className="text-gray-800 font-medium">{checkout.customer_name}</p>
                            </div>
                            {checkout.customer_document && (
                              <div>
                                <p className="text-gray-500 text-xs">CPF/CNPJ</p>
                                <p className="text-gray-800 font-medium">{checkout.customer_document}</p>
                              </div>
                            )}
                            <div>
                              <p className="text-gray-500 text-xs">E-mail</p>
                              <p className="text-gray-800 font-medium break-all">{checkout.customer_email}</p>
                            </div>
                          </div>
                        </div>

                        {checkout.customer_address && typeof checkout.customer_address === 'object' && (
                          <div className="bg-purple-50 rounded-lg p-4 border border-purple-100">
                            <h4 className="font-semibold text-gray-700 mb-2 text-xs uppercase tracking-wide">Endereço de Entrega</h4>
                            <div className="space-y-2 text-sm">
                              {(checkout.customer_address as any).street && (
                                <div>
                                  <p className="text-gray-500 text-xs">Endereço</p>
                                  <p className="text-gray-800 font-medium">{(checkout.customer_address as any).street}</p>
                                </div>
                              )}
                              {(checkout.customer_address as any).city && (
                                <div>
                                  <p className="text-gray-500 text-xs">Cidade</p>
                                  <p className="text-gray-800 font-medium">
                                    {(checkout.customer_address as any).city}
                                    {(checkout.customer_address as any).state && ` - ${(checkout.customer_address as any).state}`}
                                  </p>
                                </div>
                              )}
                              {(checkout.customer_address as any).zipcode && (
                                <div>
                                  <p className="text-gray-500 text-xs">CEP</p>
                                  <p className="text-gray-800 font-medium">{(checkout.customer_address as any).zipcode}</p>
                                </div>
                              )}
                            </div>
                          </div>
                        )}
                      </div>
                    </div>
                  )}

                  {!isProductDetailsOpen && (
                    <div className="bg-gradient-to-r from-blue-50 to-cyan-50 rounded-xl p-4 mb-6 flex items-center justify-between">
                      <div>
                        <h3 className="font-bold text-gray-800">{checkout.product_name}</h3>
                        <p className="text-sm text-gray-600">{checkout.customer_name}</p>
                      </div>
                      <div className="text-right">
                        <p className="text-2xl font-bold text-blue-600">
                          {formatCurrency(Number(checkout.final_amount || checkout.amount))}
                        </p>
                        {hasDiscount && (
                          <p className="text-xs text-green-600 font-semibold">
                            {checkout.discount_percentage}% OFF
                          </p>
                        )}
                      </div>
                    </div>
                  )}
                </div>

                {checkout.payment_status === 'waiting_payment' && !checkout.pix_qrcode && (
                  <div className="border-t border-gray-200 pt-6">
                    <div className="text-center py-8">
                      <button
                        onClick={handleGeneratePix}
                        disabled={generatingPix}
                        className="bg-green-600 hover:bg-green-700 text-white px-10 py-4 rounded-xl transition-all transform hover:scale-105 flex items-center gap-3 mx-auto disabled:opacity-50 disabled:cursor-not-allowed font-bold text-lg shadow-lg"
                      >
                        {generatingPix ? (
                          <>
                            <Loader2 className="w-6 h-6 animate-spin" />
                            Gerando seu PIX...
                          </>
                        ) : (
                          <>
                            <svg className="w-6 h-6" viewBox="0 0 512 512" fill="currentColor">
                              <path d="M242.4 292.5C247.8 287.1 257.1 287.1 262.5 292.5L339.5 369.5C353.7 383.7 372.6 391.5 392.6 391.5H407.7L310.6 488.6C280.3 518.1 231.1 518.1 200.8 488.6L103.3 391.5H112.6C132.6 391.5 151.5 383.7 165.7 369.5L242.4 292.5zM262.5 218.9C257.1 224.3 247.8 224.3 242.4 218.9L165.7 142.1C151.5 127.9 132.6 120.1 112.6 120.1H103.3L200.7 23.37C231.1-5.801 280.3-5.801 310.6 23.37L407.7 120.1H392.6C372.6 120.1 353.7 127.9 339.5 142.1L262.5 218.9zM112.6 142.1C126.4 142.1 139.1 148.3 149.7 158.1L226.4 234.8C233.6 241.1 243 245.6 252.5 245.6C261.9 245.6 271.3 241.1 278.5 234.8L355.5 157.8C365.3 148.1 378.8 142.1 392.6 142.1H430.3L488.6 200.8C518.9 231.1 518.9 280.3 488.6 310.6L430.3 368.9H392.6C378.8 368.9 365.3 362.9 355.5 353.1L278.5 276.1C264.6 262.2 240.3 262.2 226.4 276.1L149.7 352.1C139.1 362.9 126.4 368.9 112.6 368.9H80.78L23.37 310.6C-6.801 280.3-6.801 231.1 23.37 200.8L80.78 142.1H112.6z"/>
                            </svg>
                            Gerar QR Code PIX
                          </>
                        )}
                      </button>
                      <p className="text-gray-500 text-sm mt-4">
                        Pagamento 100% seguro e instantâneo
                      </p>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </>
        )}

        {checkout.pix_qrcode && (
          <div className="bg-white rounded-2xl shadow-sm p-8">
            <div className="text-center mb-8">
              <h2 className="text-3xl font-bold text-gray-800 mb-3">Já é quase seu...</h2>
              {timeRemaining > 0 && (
                <p className="text-gray-600 text-lg">
                  Pague seu pix dentro de <span className="font-bold text-orange-600">{formatTime(fixedTimer)}</span> para garantir sua compra.
                </p>
              )}
            </div>

            <div className="flex justify-center mb-6">
              <div className="relative">
                <div className="absolute -top-2 -left-2">
                  <Clock className="w-6 h-6 text-gray-400" />
                </div>
                <div className="bg-gradient-to-br from-green-50 to-emerald-50 p-2 rounded-xl">
                  <svg className="w-14 h-14 text-green-600" viewBox="0 0 100 100" fill="none" stroke="currentColor">
                    <rect x="20" y="30" width="25" height="40" strokeWidth="3" rx="3" />
                    <circle cx="32.5" cy="45" r="2" fill="currentColor" />
                    <circle cx="32.5" cy="55" r="2" fill="currentColor" />
                    <path d="M50 40 L50 60 M50 60 L65 50" strokeWidth="3" strokeLinecap="round" />
                  </svg>
                </div>
              </div>
            </div>

            <p className="text-center text-gray-700 mb-4 text-base">Aponte a câmera do seu celular</p>

            <div className="bg-white rounded-xl p-3 mb-5 border-2 border-gray-200 shadow-sm">
              {qrCodeImage && (
                <img src={qrCodeImage} alt="QR Code PIX" className="w-full max-w-[200px] mx-auto" />
              )}
            </div>

            <div className="bg-yellow-50 rounded-lg p-3 mb-5 text-center border border-yellow-200">
              <div className="flex items-center justify-center gap-2">
                <Loader2 className="w-4 h-4 text-yellow-600 animate-spin" />
                <span className="font-semibold text-sm text-yellow-800">Aguardando pagamento</span>
              </div>
            </div>

            <div className="mb-8">
              <div className="bg-gray-50 rounded-xl p-4 mb-4 border-2 border-dashed border-gray-300">
                <input
                  type="text"
                  value={checkout.pix_qrcode}
                  readOnly
                  className="w-full bg-transparent text-gray-700 text-sm font-mono text-center outline-none break-all"
                />
              </div>
              <button
                onClick={handleCopyPix}
                className="w-full bg-[#32BCAD] hover:bg-[#2BA89B] text-white px-8 py-5 rounded-xl transition-all flex items-center justify-center gap-3 font-bold text-xl shadow-lg transform hover:scale-[1.02] active:scale-[0.98]"
              >
                {copied ? (
                  <>
                    <Check className="w-7 h-7" />
                    Código copiado!
                  </>
                ) : (
                  <>
                    <Copy className="w-7 h-7" />
                    Copiar código pix
                  </>
                )}
              </button>
            </div>

            <div className="text-center mb-6">
              <p className="text-xl font-bold text-gray-800 mb-1">
                Valor do Pix: <span className="text-[#32BCAD]">{formatCurrency(Number(checkout.final_amount || checkout.amount))}</span>
              </p>
            </div>

            <div className="mt-6 bg-gray-100 rounded-xl p-4 text-center">
              <p className="text-xs text-gray-600">
                O beneficiário do PIX é BESTFY PAGAMENTOS INTELIGENTES LTDA, a empresa que gerencia nossos pagamentos de forma segura.
              </p>
            </div>

            {/* Footer - Pagamento Seguro */}
            <div className="mt-8 bg-gray-100 -mx-6 px-6 py-8 rounded-b-2xl">
              <div className="flex flex-col items-center">
                <div className="flex items-center gap-2">
                  <Lock className="w-6 h-6 text-gray-600" />
                  <div className="text-center">
                    <p className="text-sm font-bold text-gray-800">PAGAMENTO</p>
                    <p className="text-sm text-gray-600">100% SEGURO</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
