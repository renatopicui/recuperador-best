// ============================================
// FORÇAR REDIRECIONAMENTO AGORA
// Cole este código no Console do Navegador (F12)
// ============================================

// Buscar thank_you_slug do banco
const checkoutSlug = '7huoo30x'; // ou qualquer outro slug
const { createClient } = supabase;

(async () => {
  try {
    // Criar cliente Supabase
    const SUPABASE_URL = 'SEU_SUPABASE_URL_AQUI';
    const SUPABASE_ANON_KEY = 'SUA_ANON_KEY_AQUI';
    
    const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    
    // Buscar thank_you_slug
    const { data, error } = await supabaseClient
      .from('checkout_links')
      .select('thank_you_slug, payment_id')
      .eq('checkout_slug', checkoutSlug)
      .single();
    
    if (error) throw error;
    
    if (data && data.thank_you_slug) {
      console.log('✅ thank_you_slug encontrado:', data.thank_you_slug);
      console.log('🚀 Redirecionando...');
      window.location.href = `/obrigado/${data.thank_you_slug}`;
    } else {
      console.error('❌ thank_you_slug não encontrado! Execute o script SQL primeiro.');
    }
  } catch (err) {
    console.error('❌ Erro:', err);
  }
})();

