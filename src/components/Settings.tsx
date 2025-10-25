import { useState, useEffect } from 'react';
import { Settings as SettingsIcon, Save, Clock, Info } from 'lucide-react';
import { settingsService, UserSettings } from '../services/settingsService';

export default function Settings() {
  const [settings, setSettings] = useState<UserSettings | null>(null);
  const [recoveryDelayMinutes, setRecoveryDelayMinutes] = useState(3);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    try {
      setLoading(true);
      const data = await settingsService.getUserSettings();
      
      if (data) {
        setSettings(data);
        setRecoveryDelayMinutes(data.recovery_email_delay_minutes);
      } else {
        // Usar valores padrão
        const defaults = settingsService.getDefaultSettings();
        setRecoveryDelayMinutes(defaults.recovery_email_delay_minutes || 3);
      }
    } catch (err: any) {
      console.error('Erro ao carregar configurações:', err);
      setError('Erro ao carregar configurações');
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    try {
      setError('');
      setSuccess('');
      setSaving(true);

      // Validar
      if (recoveryDelayMinutes < 1 || recoveryDelayMinutes > 60) {
        setError('O tempo deve estar entre 1 e 60 minutos');
        return;
      }

      await settingsService.saveUserSettings({
        recovery_email_delay_minutes: recoveryDelayMinutes,
      });

      setSuccess('Configurações salvas com sucesso!');
      
      // Recarregar configurações
      await loadSettings();

      // Limpar mensagem de sucesso após 3 segundos
      setTimeout(() => setSuccess(''), 3000);
    } catch (err: any) {
      console.error('Erro ao salvar:', err);
      setError(err.message || 'Erro ao salvar configurações');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-400">Carregando configurações...</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <SettingsIcon className="w-8 h-8 text-blue-500" />
        <div>
          <h1 className="text-2xl font-bold text-white">Configurações</h1>
          <p className="text-gray-400">Personalize o comportamento do sistema</p>
        </div>
      </div>

      {/* Mensagens */}
      {error && (
        <div className="bg-red-500/10 border border-red-500/50 text-red-400 px-4 py-3 rounded-lg">
          {error}
        </div>
      )}

      {success && (
        <div className="bg-green-500/10 border border-green-500/50 text-green-400 px-4 py-3 rounded-lg">
          {success}
        </div>
      )}

      {/* Card de Configuração de Email de Recuperação */}
      <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
        <div className="flex items-start gap-4">
          <div className="p-3 bg-blue-500/10 rounded-lg">
            <Clock className="w-6 h-6 text-blue-500" />
          </div>
          
          <div className="flex-1">
            <h2 className="text-xl font-semibold text-white mb-2">
              Email de Recuperação de Vendas
            </h2>
            
            <div className="bg-blue-500/10 border border-blue-500/20 rounded-lg p-4 mb-4">
              <div className="flex items-start gap-2">
                <Info className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                <p className="text-sm text-blue-300">
                  Configure após quanto tempo (em minutos) o sistema deve enviar um email 
                  de recuperação para transações que ainda não foram pagas.
                </p>
              </div>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-gray-300 mb-2 font-medium">
                  Aguardar quantos minutos antes de enviar o email?
                </label>
                
                <div className="flex items-center gap-4">
                  <input
                    type="number"
                    min="1"
                    max="60"
                    value={recoveryDelayMinutes}
                    onChange={(e) => setRecoveryDelayMinutes(Number(e.target.value))}
                    className="w-32 bg-gray-700/50 border border-gray-600 rounded-lg px-4 py-3 text-white text-center text-xl font-semibold focus:outline-none focus:border-blue-500"
                  />
                  
                  <span className="text-gray-400">minutos</span>
                </div>
                
                <p className="text-sm text-gray-500 mt-2">
                  Valor entre 1 e 60 minutos (padrão: 3 minutos)
                </p>
              </div>

              {/* Visualização do tempo */}
              <div className="bg-gray-700/30 rounded-lg p-4 border border-gray-600">
                <p className="text-sm text-gray-400 mb-2">Como funciona:</p>
                <div className="space-y-2 text-sm">
                  <div className="flex items-center gap-2">
                    <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                    <span className="text-gray-300">
                      <strong className="text-white">Agora:</strong> Transação recebida
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="w-2 h-2 bg-yellow-500 rounded-full"></div>
                    <span className="text-gray-300">
                      <strong className="text-white">Após {recoveryDelayMinutes} minuto{recoveryDelayMinutes !== 1 ? 's' : ''}:</strong> Sistema verifica status
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="w-2 h-2 bg-blue-500 rounded-full"></div>
                    <span className="text-gray-300">
                      Se ainda não pago → Email de recuperação é enviado
                    </span>
                  </div>
                </div>
              </div>

              <button
                onClick={handleSave}
                disabled={saving}
                className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white font-medium py-3 px-6 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <Save className="w-5 h-5" />
                {saving ? 'Salvando...' : 'Salvar Configurações'}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Informações adicionais */}
      <div className="bg-gray-800/30 border border-gray-700 rounded-lg p-4">
        <h3 className="text-sm font-semibold text-gray-300 mb-2">ℹ️ Informações</h3>
        <ul className="text-sm text-gray-400 space-y-1">
          <li>• As configurações são aplicadas apenas às suas transações</li>
          <li>• Outros usuários da plataforma têm suas próprias configurações independentes</li>
          <li>• O email só é enviado se a transação ainda estiver com status "aguardando pagamento"</li>
          <li>• Um checkout com desconto de 20% é gerado automaticamente no email</li>
        </ul>
      </div>
    </div>
  );
}

