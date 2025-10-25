// ===================================================================
// 🔥 FORÇAR REDIRECIONAMENTO AGORA - EXECUTE NO CONSOLE DO NAVEGADOR
// ===================================================================
// Abra o Console (F12 → Console) na página do checkout e cole este código
// ===================================================================

console.log('🔥 Forçando redirecionamento...');

// Importar supabase
const { supabase } = await import('/src/services/supabaseService.ts');

// Buscar o checkout
const slug = window.location.pathname.split('/checkout/')[1];
console.log('📍 Checkout slug:', slug);

// Buscar dados do banco
const { data: checkoutData, error } = await supabase
  .from('checkout_links')
  .select('id, thank_you_slug, payment_id, status')
  .eq('checkout_slug', slug)
  .single();

if (error) {
  console.error('❌ Erro ao buscar checkout:', error);
} else {
  console.log('✅ Checkout encontrado:', checkoutData);
  
  // Se não tem thank_you_slug, gerar agora
  if (!checkoutData.thank_you_slug) {
    console.log('⚠️ thank_you_slug não existe, gerando...');
    
    const newSlug = 'ty-' + Math.random().toString(36).substr(2, 12);
    
    const { error: updateError } = await supabase
      .from('checkout_links')
      .update({ thank_you_slug: newSlug })
      .eq('id', checkoutData.id);
    
    if (updateError) {
      console.error('❌ Erro ao gerar slug:', updateError);
    } else {
      console.log('✅ thank_you_slug gerado:', newSlug);
      checkoutData.thank_you_slug = newSlug;
    }
  }
  
  // REDIRECIONAR AGORA
  if (checkoutData.thank_you_slug) {
    console.log('🎉 Redirecionando para:', `/obrigado/${checkoutData.thank_you_slug}`);
    window.location.href = `/obrigado/${checkoutData.thank_you_slug}`;
  } else {
    console.error('❌ Não foi possível obter thank_you_slug');
  }
}

