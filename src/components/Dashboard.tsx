import { useEffect, useState } from 'react';
import { User } from '@supabase/supabase-js';
import { authService } from '../services/authService';
import { bestfyService } from '../services/bestfyService';
import { supabase } from '../services/supabaseService';
import { Payment, CheckoutLink } from '../types/bestfy';
import { LogOut, RefreshCw, CreditCard, Clock, XCircle, CheckCircle2, DollarSign, Mail, Eye, TrendingUp, Link2, Send } from 'lucide-react';
import { apiKeyService } from '../services/apiKeyService';

interface DashboardProps {
  user: User;
}

export default function Dashboard({ user }: DashboardProps) {
  const [payments, setPayments] = useState<Payment[]>([]);
  const [checkoutLinks, setCheckoutLinks] = useState<CheckoutLink[]>([]);
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);
  const [showApiKeyModal, setShowApiKeyModal] = useState(false);
  const [savingApiKey, setSavingApiKey] = useState(false);
  const [apiKeyInput, setApiKeyInput] = useState('');
  const [apiKeyError, setApiKeyError] = useState('');

  useEffect(() => {
    ensureApiKey().then(() => {
      loadPayments();
      loadCheckoutLinks();
    });
  }, []);

  const ensureApiKey = async () => {
    try {
      const key = await apiKeyService.getApiKey();
      if (!key) {
        setShowApiKeyModal(true);
      }
    } catch (e) {
      // silenciosamente não bloqueia, mas abre modal por segurança
      setShowApiKeyModal(true);
    }
  };

  const loadPayments = async () => {
    try {
      const data = await bestfyService.getPayments();
      setPayments(data);
    } catch (error) {
      console.error('Erro ao carregar pagamentos:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadCheckoutLinks = async () => {
    try {
      const { data, error } = await supabase
        .from('checkout_links')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setCheckoutLinks(data || []);
    } catch (error) {
      console.error('Erro ao carregar checkout links:', error);
    }
  };

  const handleSync = async () => {
    setSyncing(true);
    try {
      await bestfyService.syncPayments();
      await loadPayments();
      await loadCheckoutLinks();
    } catch (error) {
      console.error('Erro ao sincronizar:', error);
    } finally {
      setSyncing(false);
    }
  };

  const handleLogout = async () => {
    await authService.signOut();
  };

  const handleSaveApiKey = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!apiKeyInput.trim()) {
      setApiKeyError('Informe sua chave da Bestfy');
      return;
    }
    setApiKeyError('');
    setSavingApiKey(true);
    try {
      await apiKeyService.saveApiKey(apiKeyInput.trim());
      setShowApiKeyModal(false);
      setApiKeyInput('');
      // recarrega dados após configurar chave
      await loadPayments();
      await loadCheckoutLinks();
    } catch (err: any) {
      setApiKeyError(err.message || 'Falha ao salvar chave');
    } finally {
      setSavingApiKey(false);
    }
  };

  const totalTransactions = payments.length;
  const paidPayments = payments.filter(p => p.status === 'paid');
  const pendingPayments = payments.filter(p => p.status === 'waiting_payment');
  
  // 🎯 VENDAS RECUPERADAS: Checkouts que têm thank_you_slug (foram pagos e redirecionados)
  const recoveredCheckouts = checkoutLinks.filter(cl => cl.thank_you_slug !== null && cl.thank_you_slug !== '');
  const recoveredPayments = recoveredCheckouts.length;
  
  // 💰 VALORES RECUPERADOS: Soma dos valores dos checkouts recuperados
  const recoveredAmount = recoveredCheckouts.reduce((sum, cl) => {
    const amount = cl.final_amount || cl.amount || 0;
    return sum + Number(amount);
  }, 0);
  
  // 📧 E-mails enviados
  const emailsSent = payments.filter(p => p.recovery_email_sent_at).length;
  
  // 📊 Total de acessos aos checkouts
  const totalCheckoutAccess = checkoutLinks.reduce((sum, cl) => sum + (cl.access_count || 0), 0);
  
  // 📈 TAXA DE CONVERSÃO: (checkouts recuperados / total de checkouts) * 100
  const totalCheckouts = checkoutLinks.length;
  const conversionRate = totalCheckouts > 0 ? (recoveredPayments / totalCheckouts) * 100 : 0;

  const stats = {
    total: totalTransactions,
    paid: paidPayments.length,
    paidAmount: paidPayments.reduce((sum, p) => sum + Number(p.amount), 0),
    pending: pendingPayments.length,
    pendingAmount: pendingPayments.reduce((sum, p) => sum + Number(p.amount), 0),
    emailsSent,
    recovered: recoveredPayments, // recoveredPayments já é um número (linha 113)
    recoveredAmount,
    conversionRate,
    checkoutAccess: totalCheckoutAccess,
  };

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL',
    }).format(value / 100);
  };

  const getCheckoutLink = (paymentId: string) => {
    const checkout = checkoutLinks.find(cl => cl.payment_id === paymentId);
    return checkout;
  };

  const handleCheckoutClick = (checkout: CheckoutLink) => {
    const checkoutUrl = `${window.location.origin}/checkout/${checkout.checkout_slug}`;
    window.open(checkoutUrl, '_blank');
  };

  const getStatusBadge = (status: string) => {
    const statusMap: Record<string, { label: string; color: string; icon: any }> = {
      paid: { label: 'Pago', color: 'bg-green-500/20 text-green-400', icon: CheckCircle2 },
      waiting_payment: { label: 'Pendente', color: 'bg-yellow-500/20 text-yellow-400', icon: Clock },
      cancelled: { label: 'Cancelado', color: 'bg-red-500/20 text-red-400', icon: XCircle },
      expired: { label: 'Expirado', color: 'bg-gray-500/20 text-gray-400', icon: XCircle },
    };

    const config = statusMap[status] || statusMap.waiting_payment;
    const Icon = config.icon;

    return (
      <span className={`inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm font-medium ${config.color}`}>
        <Icon className="w-4 h-4" />
        {config.label}
      </span>
    );
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 flex items-center justify-center">
        <div className="text-white text-xl">Carregando...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6">
      <div className="max-w-7xl mx-auto">
        {showApiKeyModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
            <div className="bg-gray-800 border border-gray-700 rounded-xl p-6 w-full max-w-md mx-4">
              <h2 className="text-xl font-bold text-white mb-2">Configurar API Key da Bestfy</h2>
              <p className="text-gray-400 mb-4">Para criar cobranças PIX, insira sua chave de API da Bestfy. Ela será validada e salva com segurança.</p>
              {apiKeyError && (
                <div className="bg-red-500/10 border border-red-500/50 text-red-400 px-4 py-2 rounded-lg mb-4">{apiKeyError}</div>
              )}
              <form onSubmit={handleSaveApiKey} className="space-y-4">
                <div>
                  <label className="block text-gray-300 mb-2">API Key</label>
                  <input
                    type="password"
                    value={apiKeyInput}
                    onChange={(e) => setApiKeyInput(e.target.value)}
                    className="w-full bg-gray-700/50 border border-gray-600 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-blue-500"
                    placeholder="Insira sua chave Bestfy"
                    required
                  />
                </div>
                <div className="flex items-center justify-end gap-2">
                  <button
                    type="button"
                    disabled={savingApiKey}
                    onClick={() => setShowApiKeyModal(false)}
                    className="px-4 py-2 rounded-lg bg-gray-700 text-gray-200 hover:bg-gray-600 disabled:opacity-50"
                  >
                    Depois
                  </button>
                  <button
                    type="submit"
                    disabled={savingApiKey}
                    className="px-4 py-2 rounded-lg bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50"
                  >
                    {savingApiKey ? 'Validando...' : 'Salvar Chave'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold text-white mb-2">Dashboard</h1>
            <p className="text-gray-400">{user.email}</p>
          </div>
          <div className="flex gap-3">
            <button
              onClick={handleSync}
              disabled={syncing}
              className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg transition-colors disabled:opacity-50"
            >
              <RefreshCw className={`w-4 h-4 ${syncing ? 'animate-spin' : ''}`} />
              {syncing ? 'Sincronizando...' : 'Sincronizar'}
            </button>
            <button
              onClick={handleLogout}
              className="flex items-center gap-2 bg-gray-700 hover:bg-gray-600 text-white px-4 py-2 rounded-lg transition-colors"
            >
              <LogOut className="w-4 h-4" />
              Sair
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-6">
          <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4">
              <div className="bg-blue-500/20 p-3 rounded-lg">
                <CreditCard className="w-6 h-6 text-blue-400" />
              </div>
              <div>
                <p className="text-gray-400 text-sm">Total de Transações</p>
                <p className="text-2xl font-bold text-white">{stats.total}</p>
              </div>
            </div>
          </div>

          <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4">
              <div className="bg-green-500/20 p-3 rounded-lg">
                <CheckCircle2 className="w-6 h-6 text-green-400" />
              </div>
              <div>
                <p className="text-gray-400 text-sm">Pagamentos Confirmados</p>
                <p className="text-2xl font-bold text-white">{stats.paid}</p>
                <p className="text-green-400 text-sm">{formatCurrency(stats.paidAmount)}</p>
              </div>
            </div>
          </div>

          <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4">
              <div className="bg-yellow-500/20 p-3 rounded-lg">
                <Clock className="w-6 h-6 text-yellow-400" />
              </div>
              <div>
                <p className="text-gray-400 text-sm">Aguardando Pagamento</p>
                <p className="text-2xl font-bold text-white">{stats.pending}</p>
                <p className="text-yellow-400 text-sm">{formatCurrency(stats.pendingAmount)}</p>
              </div>
            </div>
          </div>

          <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4">
              <div className="bg-purple-500/20 p-3 rounded-lg">
                <Mail className="w-6 h-6 text-purple-400" />
              </div>
              <div>
                <p className="text-gray-400 text-sm">E-mails de Recuperação</p>
                <p className="text-2xl font-bold text-white">{stats.emailsSent}</p>
              </div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4">
              <div className="bg-emerald-500/20 p-3 rounded-lg">
                <CheckCircle2 className="w-6 h-6 text-emerald-400" />
              </div>
              <div>
                <p className="text-gray-400 text-sm">Vendas Recuperadas</p>
                <p className="text-2xl font-bold text-white">{stats.recovered}</p>
              </div>
            </div>
          </div>

          <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4">
              <div className="bg-green-500/20 p-3 rounded-lg">
                <DollarSign className="w-6 h-6 text-green-400" />
              </div>
              <div>
                <p className="text-gray-400 text-sm">Valores Recuperados</p>
                <p className="text-2xl font-bold text-white">{formatCurrency(stats.recoveredAmount)}</p>
              </div>
            </div>
          </div>

          <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4">
              <div className="bg-cyan-500/20 p-3 rounded-lg">
                <TrendingUp className="w-6 h-6 text-cyan-400" />
              </div>
              <div>
                <p className="text-gray-400 text-sm">Taxa de Conversão</p>
                <p className="text-2xl font-bold text-white">{stats.conversionRate.toFixed(1)}%</p>
              </div>
            </div>
          </div>

          <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4">
              <div className="bg-orange-500/20 p-3 rounded-lg">
                <Eye className="w-6 h-6 text-orange-400" />
              </div>
              <div>
                <p className="text-gray-400 text-sm">Acessos ao Checkout</p>
                <p className="text-2xl font-bold text-white">{stats.checkoutAccess}</p>
              </div>
            </div>
          </div>
        </div>

        {recoveredPayments.length > 0 && (
          <div className="bg-gradient-to-r from-emerald-900/30 to-green-900/30 backdrop-blur-sm border border-emerald-700/50 rounded-xl p-6 mb-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="bg-emerald-500/20 p-2 rounded-lg">
                  <CheckCircle2 className="w-6 h-6 text-emerald-400" />
                </div>
                <div>
                  <h2 className="text-xl font-bold text-white">🎉 Transações Recuperadas</h2>
                  <p className="text-emerald-400 text-sm">Vendas que foram recuperadas através do sistema de checkout</p>
                </div>
              </div>
              <div className="text-right">
                <p className="text-3xl font-bold text-emerald-400">{formatCurrency(stats.recoveredAmount)}</p>
                <p className="text-sm text-gray-400">{stats.recovered} vendas recuperadas</p>
              </div>
            </div>
            
            <div className="bg-gray-900/50 rounded-lg p-4">
              <div className="space-y-2">
                {recoveredPayments.slice(0, 5).map((payment) => (
                  <div key={payment.id} className="flex items-center justify-between py-2 border-b border-gray-700/50 last:border-0">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 bg-emerald-600 rounded-full flex items-center justify-center text-white text-sm font-medium">
                        {payment.customer_name.charAt(0).toUpperCase()}
                      </div>
                      <div>
                        <p className="text-white font-medium text-sm">{payment.customer_name}</p>
                        <p className="text-gray-400 text-xs">{payment.product_name}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-emerald-400 font-bold">{formatCurrency(Number(payment.amount))}</p>
                      <p className="text-gray-400 text-xs">
                        {payment.recovered_at ? new Date(payment.recovered_at).toLocaleDateString('pt-BR') : 'N/A'}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
          <h2 className="text-xl font-bold text-white mb-4">Transações Recentes</h2>

          {payments.length === 0 ? (
            <div className="text-center py-12">
              <CreditCard className="w-16 h-16 text-gray-600 mx-auto mb-4" />
              <p className="text-gray-400">Nenhum pagamento encontrado</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-700">
                    <th className="text-left text-gray-400 font-medium py-3 px-4">Cliente</th>
                    <th className="text-left text-gray-400 font-medium py-3 px-4">Produto</th>
                    <th className="text-left text-gray-400 font-medium py-3 px-4">Status</th>
                    <th className="text-center text-gray-400 font-medium py-3 px-4">Checkout</th>
                    <th className="text-center text-gray-400 font-medium py-3 px-4">E-mail</th>
                    <th className="text-left text-gray-400 font-medium py-3 px-4">Valor</th>
                    <th className="text-left text-gray-400 font-medium py-3 px-4">Data</th>
                  </tr>
                </thead>
                <tbody>
                  {payments.map((payment) => {
                    const checkout = getCheckoutLink(payment.id);
                    const emailSent = payment.recovery_email_sent_at;

                    return (
                      <tr key={payment.id} className="border-b border-gray-700/50 hover:bg-gray-700/30 transition-colors">
                        <td className="py-4 px-4">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center text-white font-medium">
                              {payment.customer_name.charAt(0).toUpperCase()}
                            </div>
                            <div>
                              <p className="text-white font-medium">{payment.customer_name}</p>
                              <p className="text-gray-400 text-sm">{payment.customer_email}</p>
                            </div>
                          </div>
                        </td>
                        <td className="py-4 px-4 text-gray-300">{payment.product_name}</td>
                        <td className="py-4 px-4">
                          <div className="flex items-center gap-2">
                            {getStatusBadge(payment.status)}
                            {/* ✅ LÓGICA CORRIGIDA: Se thank_you_slug existe = venda recuperada */}
                            {checkout && checkout.thank_you_slug && (
                              <span 
                                className="inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-xs font-bold bg-gradient-to-r from-emerald-500/20 to-green-500/20 text-emerald-400 border-2 border-emerald-500/40 shadow-sm"
                                title={`🎉 Venda recuperada através do nosso checkout!\nRecuperado em: ${checkout.thank_you_accessed_at ? new Date(checkout.thank_you_accessed_at).toLocaleString('pt-BR') : 'N/A'}`}
                              >
                                <CheckCircle2 className="w-4 h-4" />
                                💰 RECUPERADO
                              </span>
                            )}
                          </div>
                        </td>
                        <td className="py-4 px-4 text-center">
                          {checkout ? (
                            <button
                              onClick={() => handleCheckoutClick(checkout)}
                              className="inline-flex items-center justify-center w-8 h-8 bg-green-500/20 hover:bg-green-500/30 rounded-lg transition-colors group"
                              title="Abrir checkout"
                            >
                              <CheckCircle2 className="w-5 h-5 text-green-400 group-hover:text-green-300" />
                            </button>
                          ) : (
                            <span className="text-gray-600">-</span>
                          )}
                        </td>
                        <td className="py-4 px-4 text-center">
                          {emailSent ? (
                            <span className="inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-medium bg-green-500/20 text-green-400">
                              <Send className="w-3 h-3" />
                              Enviado
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-medium bg-gray-500/20 text-gray-400">
                              <Clock className="w-3 h-3" />
                              Pendente
                            </span>
                          )}
                        </td>
                        <td className="py-4 px-4 text-white font-medium">{formatCurrency(Number(payment.amount))}</td>
                        <td className="py-4 px-4 text-gray-400">
                          {new Date(payment.created_at).toLocaleDateString('pt-BR')}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
