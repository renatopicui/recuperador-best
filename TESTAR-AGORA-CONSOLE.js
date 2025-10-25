// ===================================================================
// 🔥 TESTAR AGORA - EXECUTE NO CONSOLE (F12) na página do checkout
// ===================================================================
// Este script força o redirecionamento IMEDIATAMENTE
// Use enquanto não executa o SQL no Supabase
// ===================================================================

console.log('🔍 Iniciando teste de redirecionamento...');

// Pegar o slug do checkout da URL
const slug = window.location.pathname.split('/checkout/')[1];
console.log('📍 Checkout slug:', slug);

// Importar supabase
const { supabase } = await import('/src/services/supabaseService.ts');

// Buscar dados do checkout no banco
console.log('🔄 Buscando dados no banco...');
const { data: checkout, error } = await supabase
  .from('checkout_links')
  .select(`
    id,
    checkout_slug,
    thank_you_slug,
    payment_id,
    status,
    payments!checkout_links_payment_id_fkey (
      status,
      bestfy_id
    )
  `)
  .eq('checkout_slug', slug)
  .single();

if (error) {
  console.error('❌ Erro ao buscar checkout:', error);
  throw error;
}

console.log('✅ Checkout encontrado:', checkout);
console.log('📊 Status do checkout:', checkout.status);
console.log('💰 Status do pagamento:', checkout.payments?.status);
console.log('🔗 Thank you slug:', checkout.thank_you_slug);

// Verificar se o pagamento foi aprovado
if (checkout.payments?.status === 'paid') {
  console.log('✅ PAGAMENTO CONFIRMADO!');
  
  // Se não tem thank_you_slug, criar um agora
  if (!checkout.thank_you_slug) {
    console.log('⚠️ thank_you_slug não existe, criando...');
    
    const newSlug = 'ty-' + Math.random().toString(36).substring(2, 14);
    
    const { error: updateError } = await supabase
      .from('checkout_links')
      .update({ thank_you_slug: newSlug })
      .eq('id', checkout.id);
    
    if (updateError) {
      console.error('❌ Erro ao criar thank_you_slug:', updateError);
    } else {
      console.log('✅ thank_you_slug criado:', newSlug);
      checkout.thank_you_slug = newSlug;
    }
  }
  
  // REDIRECIONAR
  if (checkout.thank_you_slug) {
    console.log('🎉 REDIRECIONANDO AGORA para:', `/obrigado/${checkout.thank_you_slug}`);
    setTimeout(() => {
      window.location.href = `/obrigado/${checkout.thank_you_slug}`;
    }, 1000);
  } else {
    console.error('❌ Não foi possível obter thank_you_slug');
  }
} else {
  console.log('⏳ Pagamento ainda não confirmado');
  console.log('   Status atual:', checkout.payments?.status);
  console.log('   Aguardando webhook da Bestfy...');
}

// ===================================================================
// 📋 RESUMO
// ===================================================================
console.log('\n===================================================================');
console.log('📋 RESUMO:');
console.log('===================================================================');
console.log('Checkout slug:', checkout.checkout_slug);
console.log('Status checkout:', checkout.status);
console.log('Status pagamento:', checkout.payments?.status);
console.log('Thank you slug:', checkout.thank_you_slug || '❌ NÃO EXISTE');
console.log('ID Bestfy:', checkout.payments?.bestfy_id);
console.log('===================================================================');

if (checkout.payments?.status === 'paid' && checkout.thank_you_slug) {
  console.log('✅ TUDO PRONTO - Redirecionando em 1 segundo...');
} else if (checkout.payments?.status === 'paid' && !checkout.thank_you_slug) {
  console.log('⚠️ PAGO MAS SEM SLUG - Criando e redirecionando...');
} else {
  console.log('⏳ AGUARDANDO CONFIRMAÇÃO DE PAGAMENTO');
}

