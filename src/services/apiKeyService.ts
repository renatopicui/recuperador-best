import { supabase } from './supabaseService';

export const apiKeyService = {
  async saveApiKey(apiKey: string): Promise<void> {
    console.log('🔑 Iniciando salvamento da API key...');
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) throw new Error('User not authenticated');
    console.log('✅ Usuário autenticado:', user.id);

    // Busca o id da empresa da Bestfy para mapear transações
    let companyId: string | null = null;
    try {
      // Tenta decodificar base64; se falhar, usa o valor original
      let candidate = apiKey;
      try {
        candidate = atob(apiKey);
        if (/[^\x20-\x7E]/.test(candidate)) {
          candidate = apiKey;
        }
      } catch (_) {
        candidate = apiKey;
      }

      // Tenta buscar company com Basic Auth (chave:x) em ambos domínios
      const companyEndpoints = [
        'https://api.bestfybr.com.br/v1/company',
        'https://api.bestfy.com.br/v1/company'
      ];

      for (const endpoint of companyEndpoints) {
        try {
          // Basic Auth: username = chave secreta, password = "x"
          const basicAuth = btoa(`${candidate}:x`);
          
          const response = await fetch(endpoint, {
            method: 'GET',
            headers: {
              'Authorization': `Basic ${basicAuth}`,
              'Accept': 'application/json',
            },
          });

          if (response.ok) {
            const company = await response.json();
            companyId = company?.id; // O campo 'id' da resposta da company (ex: 43730)
            if (companyId) {
              console.log(`✅ Company ID encontrado: ${companyId}`);
              console.log(`✅ Salvando bestfy_company_id: ${companyId}`);
              break;
            }
          } else {
            console.warn(`⚠️ Falha ao buscar company em ${endpoint}: ${response.status}`);
          }
        } catch (error) {
          console.warn(`⚠️ Erro ao buscar company: ${error}`);
          // Continua para próximo endpoint
        }
      }
    } catch (error) {
      console.warn('⚠️ Erro ao buscar company_id:', error);
    }

    console.log('💾 Company ID capturado:', companyId || 'NULL');

    // Desativa chaves existentes
    console.log('🔄 Desativando chaves antigas...');
    const { error: deactivateError } = await supabase
      .from('api_keys')
      .update({ is_active: false })
      .eq('user_id', user.id)
      .eq('service', 'bestfy')
      .eq('is_active', true);

    if (deactivateError) {
      console.error('❌ Erro ao desativar chaves antigas:', deactivateError);
      throw deactivateError;
    }
    console.log('✅ Chaves antigas desativadas');

    // Insere nova chave com company_id
    console.log('💾 Inserindo nova chave com bestfy_company_id:', companyId);
    const { error, data } = await supabase
      .from('api_keys')
      .insert({
        user_id: user.id,
        encrypted_key: btoa(apiKey),
        service: 'bestfy',
        key_name: 'default',
        is_active: true,
        bestfy_company_id: companyId,
      })
      .select();

    if (error) {
      console.error('❌ Erro ao inserir chave:', error);
      console.error('❌ Código do erro:', error.code);
      console.error('❌ Mensagem:', error.message);
      console.error('❌ Detalhes:', error.details);
      throw new Error(`Erro ao salvar chave: ${error.message}`);
    }

    console.log('✅ Chave salva com sucesso:', data);
    console.log('✅ bestfy_company_id salvo:', companyId);
  },

  async getApiKey(): Promise<string | null> {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return null;

    const { data, error } = await supabase
      .from('api_keys')
      .select('encrypted_key')
      .eq('user_id', user.id)
      .eq('is_active', true)
      .maybeSingle();

    if (error) throw error;
    // descriptografa base64 para uso local
    return data?.encrypted_key ? atob(data.encrypted_key) : null;
  },
};
