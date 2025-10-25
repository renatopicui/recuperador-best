import { useEffect, useState } from 'react';
import { CheckCircle2, Package, Mail, Loader2 } from 'lucide-react';
import { ThankYouPageData } from '../types/bestfy';
import { supabase } from '../services/supabaseService';

export default function ThankYou() {
  const [data, setData] = useState<ThankYouPageData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    loadThankYouPage();
  }, []);

  const loadThankYouPage = async () => {
    try {
      // Extrair thank_you_slug da URL
      const path = window.location.pathname;
      const slug = path.split('/obrigado/')[1];

      console.log('📥 [ThankYou] Carregando página de obrigado:', slug);

      if (!slug) {
        setError('Link inválido');
        setLoading(false);
        return;
      }

      // Primeiro, acessar a página para registrar e marcar como recuperado
      const { data: accessResult, error: accessError } = await supabase
        .rpc('access_thank_you_page', { p_thank_you_slug: slug });

      if (accessError) {
        console.error('❌ [ThankYou] Erro ao acessar página:', accessError);
        throw accessError;
      }

      console.log('✅ [ThankYou] Página acessada:', accessResult);

      // Agora buscar os dados para exibir
      const { data: pageData, error: pageError } = await supabase
        .rpc('get_thank_you_page', { p_thank_you_slug: slug });

      if (pageError) throw pageError;

      if (!pageData) {
        setError('Página não encontrada');
        setLoading(false);
        return;
      }

      console.log('✅ [ThankYou] Dados carregados:', pageData);
      setData(pageData as ThankYouPageData);
    } catch (err: any) {
      console.error('❌ [ThankYou] Erro:', err);
      setError(err.message || 'Erro ao carregar página');
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL',
    }).format(value / 100);
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-white flex items-center justify-center">
        <div className="text-center">
          <Loader2 className="w-12 h-12 text-blue-600 animate-spin mx-auto mb-4" />
          <p className="text-gray-600">Carregando...</p>
        </div>
      </div>
    );
  }

  if (error || !data) {
    return (
      <div className="min-h-screen bg-white flex items-center justify-center p-4">
        <div className="text-center max-w-md">
          <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <CheckCircle2 className="w-10 h-10 text-red-600" />
          </div>
          <h1 className="text-2xl font-bold text-gray-800 mb-2">Ops!</h1>
          <p className="text-gray-600">{error || 'Página não encontrada'}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-green-50 via-emerald-50 to-teal-50 flex items-center justify-center p-4">
      <div className="max-w-2xl w-full">
        {/* Confetti Animation */}
        <div className="text-center mb-8 animate-bounce">
          <div className="text-6xl mb-4">🎉</div>
        </div>

        <div className="bg-white rounded-3xl shadow-2xl overflow-hidden">
          {/* Header Success */}
          <div className="bg-gradient-to-r from-green-600 to-emerald-600 text-white p-8 text-center">
            <div className="w-20 h-20 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center mx-auto mb-4 animate-pulse">
              <CheckCircle2 className="w-12 h-12" />
            </div>
            <h1 className="text-4xl font-bold mb-2">Pagamento Confirmado!</h1>
            <p className="text-xl text-green-100">Obrigado pela sua compra! 🎊</p>
          </div>

          {/* Content */}
          <div className="p-8">
            <div className="bg-gradient-to-br from-gray-50 to-gray-100 rounded-2xl p-6 mb-6">
              <h2 className="text-lg font-bold text-gray-800 mb-4 flex items-center gap-2">
                <Package className="w-5 h-5 text-blue-600" />
                Detalhes do Pedido
              </h2>
              
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-gray-600">Produto:</span>
                  <span className="font-semibold text-gray-800">{data.product_name}</span>
                </div>
                
                <div className="flex justify-between items-center">
                  <span className="text-gray-600">Cliente:</span>
                  <span className="font-semibold text-gray-800">{data.customer_name}</span>
                </div>
                
                <div className="flex justify-between items-center">
                  <span className="text-gray-600">E-mail:</span>
                  <span className="font-semibold text-gray-800">{data.customer_email}</span>
                </div>
                
                <div className="flex justify-between items-center pt-4 border-t-2 border-gray-300">
                  <span className="text-gray-800 font-bold text-lg">Valor Pago:</span>
                  <span className="text-3xl font-bold text-green-600">
                    {formatCurrency(Number(data.final_amount || data.amount))}
                  </span>
                </div>
              </div>
            </div>

            {/* Email Confirmation Info */}
            <div className="bg-blue-50 rounded-xl p-6 mb-6 border-2 border-blue-200">
              <div className="flex items-start gap-3">
                <div className="bg-blue-100 p-2 rounded-lg">
                  <Mail className="w-5 h-5 text-blue-600" />
                </div>
                <div>
                  <h3 className="font-bold text-gray-800 mb-1">Confirmação por E-mail</h3>
                  <p className="text-sm text-gray-600">
                    Você receberá um e-mail de confirmação em <strong>{data.customer_email}</strong> com todos os detalhes do seu pedido em breve.
                  </p>
                </div>
              </div>
            </div>

            {/* Success Message */}
            <div className="bg-gradient-to-r from-green-100 to-emerald-100 rounded-xl p-6 border-2 border-green-300">
              <div className="text-center">
                <h3 className="text-xl font-bold text-gray-800 mb-2">
                  ✨ Sua compra foi processada com sucesso!
                </h3>
                <p className="text-gray-700">
                  Obrigado por escolher nossos serviços. Se tiver alguma dúvida, entre em contato conosco através do e-mail de confirmação.
                </p>
              </div>
            </div>

            {/* Transaction ID (small) */}
            <div className="mt-6 text-center">
              <p className="text-xs text-gray-400">
                ID da Transação: {data.payment_bestfy_id}
              </p>
            </div>
          </div>
        </div>

        {/* Footer Note */}
        <div className="mt-6 text-center">
          <p className="text-sm text-gray-600">
            Esta página confirma o recebimento do seu pagamento. Você pode fechar esta janela.
          </p>
        </div>
      </div>
    </div>
  );
}

