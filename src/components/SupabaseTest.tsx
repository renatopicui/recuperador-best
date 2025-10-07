import { useEffect, useState } from 'react';
import { supabase } from '../services/supabaseService';
import { CheckCircle2, XCircle, Loader2, Database } from 'lucide-react';

export default function SupabaseTest() {
  const [connectionStatus, setConnectionStatus] = useState<'testing' | 'connected' | 'error'>('testing');
  const [error, setError] = useState<string>('');
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    testConnection();
  }, []);

  const testConnection = async () => {
    try {
      setConnectionStatus('testing');
      setError('');

      // Teste 1: Verificar se as variáveis de ambiente estão configuradas
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

      if (!supabaseUrl || !supabaseKey) {
        throw new Error('Variáveis de ambiente VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY não configuradas');
      }

      if (supabaseUrl.includes('seu-projeto') || supabaseKey.includes('sua-chave')) {
        throw new Error('Por favor, substitua as variáveis de ambiente pelos valores reais do seu projeto Supabase');
      }

      // Teste 2: Verificar conexão com o banco
      const { data, error: dbError } = await supabase
        .from('payments')
        .select('count')
        .limit(1);

      if (dbError) {
        throw new Error(`Erro na conexão com o banco: ${dbError.message}`);
      }

      // Teste 3: Verificar autenticação
      const { data: { user: currentUser } } = await supabase.auth.getUser();
      setUser(currentUser);

      setConnectionStatus('connected');
    } catch (err: any) {
      setConnectionStatus('error');
      setError(err.message);
    }
  };

  const getStatusIcon = () => {
    switch (connectionStatus) {
      case 'testing':
        return <Loader2 className="w-6 h-6 text-blue-500 animate-spin" />;
      case 'connected':
        return <CheckCircle2 className="w-6 h-6 text-green-500" />;
      case 'error':
        return <XCircle className="w-6 h-6 text-red-500" />;
    }
  };

  const getStatusText = () => {
    switch (connectionStatus) {
      case 'testing':
        return 'Testando conexão...';
      case 'connected':
        return 'Conectado com sucesso!';
      case 'error':
        return 'Erro na conexão';
    }
  };

  const getStatusColor = () => {
    switch (connectionStatus) {
      case 'testing':
        return 'border-blue-200 bg-blue-50';
      case 'connected':
        return 'border-green-200 bg-green-50';
      case 'error':
        return 'border-red-200 bg-red-50';
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 flex items-center justify-center p-4">
      <div className="max-w-md w-full">
        <div className={`border-2 rounded-xl p-6 ${getStatusColor()}`}>
          <div className="flex items-center gap-3 mb-4">
            <Database className="w-8 h-8 text-gray-700" />
            <h1 className="text-xl font-bold text-gray-800">Teste de Conexão Supabase</h1>
          </div>

          <div className="flex items-center gap-3 mb-4">
            {getStatusIcon()}
            <span className="font-medium text-gray-700">{getStatusText()}</span>
          </div>

          {error && (
            <div className="bg-red-100 border border-red-300 text-red-700 px-4 py-3 rounded-lg mb-4">
              <p className="text-sm font-medium">Erro:</p>
              <p className="text-sm">{error}</p>
            </div>
          )}

          {connectionStatus === 'connected' && (
            <div className="bg-green-100 border border-green-300 text-green-700 px-4 py-3 rounded-lg mb-4">
              <p className="text-sm font-medium">✅ Conexão estabelecida com sucesso!</p>
              <div className="mt-2 text-xs">
                <p><strong>URL:</strong> {import.meta.env.VITE_SUPABASE_URL}</p>
                <p><strong>Usuário:</strong> {user ? user.email || 'Autenticado' : 'Não autenticado'}</p>
              </div>
            </div>
          )}

          <div className="space-y-2 text-sm text-gray-600">
            <h3 className="font-medium text-gray-800">Checklist de Configuração:</h3>
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                {import.meta.env.VITE_SUPABASE_URL ? 
                  <CheckCircle2 className="w-4 h-4 text-green-500" /> : 
                  <XCircle className="w-4 h-4 text-red-500" />
                }
                <span>VITE_SUPABASE_URL configurada</span>
              </div>
              <div className="flex items-center gap-2">
                {import.meta.env.VITE_SUPABASE_ANON_KEY ? 
                  <CheckCircle2 className="w-4 h-4 text-green-500" /> : 
                  <XCircle className="w-4 h-4 text-red-500" />
                }
                <span>VITE_SUPABASE_ANON_KEY configurada</span>
              </div>
              <div className="flex items-center gap-2">
                {connectionStatus === 'connected' ? 
                  <CheckCircle2 className="w-4 h-4 text-green-500" /> : 
                  <XCircle className="w-4 h-4 text-red-500" />
                }
                <span>Conexão com banco de dados</span>
              </div>
            </div>
          </div>

          <button
            onClick={testConnection}
            className="w-full mt-4 bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-lg transition-colors"
          >
            Testar Novamente
          </button>
        </div>

        {connectionStatus === 'error' && (
          <div className="mt-4 bg-gray-800 border border-gray-700 rounded-xl p-4">
            <h3 className="text-white font-medium mb-2">Como configurar:</h3>
            <div className="text-gray-300 text-sm space-y-2">
              <p>1. Acesse <a href="https://supabase.com" target="_blank" className="text-blue-400 hover:underline">supabase.com</a></p>
              <p>2. Crie um novo projeto ou acesse um existente</p>
              <p>3. Vá em Settings → API</p>
              <p>4. Copie a URL e a chave anon/public</p>
              <p>5. Cole no arquivo .env do projeto</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}