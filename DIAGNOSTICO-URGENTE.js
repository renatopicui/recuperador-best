// ===================================================================
// 🔥 DIAGNÓSTICO URGENTE - EXECUTAR NO CONSOLE DO NAVEGADOR
// ===================================================================
// Cole este código no Console do navegador enquanto estiver na página:
// http://localhost:5173/checkout/7huoo30x

console.log('🔍 INICIANDO DIAGNÓSTICO...');

// Importar supabase
const { supabase } = await import('/src/services/supabaseService.ts');

console.log('✅ Supabase importado');

// 1. Verificar status atual no banco
console.log('\n📊 1. VERIFICANDO STATUS NO BANCO:');
const { data: checkoutData, error: checkoutError } = await supabase
  .from('checkout_links')
  .select('*')
  .eq('checkout_slug', '7huoo30x')
  .single();

if (checkoutError) {
  console.error('❌ Erro ao buscar checkout:', checkoutError);
} else {
  console.log('✅ Checkout encontrado:', checkoutData);
  console.log('   - Status:', checkoutData.payment_status);
  console.log('   - Thank You Slug:', checkoutData.thank_you_slug);
}

// 2. Testar função RPC
console.log('\n🔧 2. TESTANDO FUNÇÃO get_checkout_by_slug:');
const { data: rpcData, error: rpcError } = await supabase
  .rpc('get_checkout_by_slug', { p_slug: '7huoo30x' });

if (rpcError) {
  console.error('❌ Erro na função RPC:', rpcError);
} else {
  console.log('✅ Função RPC retornou:', rpcData);
  console.log('   - Status:', rpcData?.payment_status);
  console.log('   - Thank You Slug:', rpcData?.thank_you_slug);
}

// 3. Verificar se existe thank_you_slug
console.log('\n🎯 3. VERIFICANDO THANK_YOU_SLUG:');
if (!checkoutData?.thank_you_slug) {
  console.error('❌ PROBLEMA: thank_you_slug NÃO EXISTE!');
  console.log('   Isso significa que a função generate_thank_you_slug não foi executada.');
  console.log('   Você precisa executar o script FIX-DEFINITIVO.sql');
} else {
  console.log('✅ thank_you_slug existe:', checkoutData.thank_you_slug);
}

// 4. Verificar função generate_thank_you_slug
console.log('\n🔧 4. VERIFICANDO SE FUNÇÃO generate_thank_you_slug EXISTE:');
const { data: funcExists, error: funcError } = await supabase
  .rpc('generate_thank_you_slug', { p_checkout_id: checkoutData?.id });

if (funcError) {
  console.error('❌ Função generate_thank_you_slug NÃO EXISTE:', funcError);
  console.log('   Você precisa executar o script FIX-DEFINITIVO.sql');
} else {
  console.log('✅ Função generate_thank_you_slug existe e retornou:', funcExists);
}

console.log('\n===================================================================');
console.log('📋 RESUMO DO DIAGNÓSTICO:');
console.log('===================================================================');
console.log('Status do checkout:', checkoutData?.payment_status);
console.log('Thank You Slug:', checkoutData?.thank_you_slug || '❌ NÃO EXISTE');
console.log('RPC funciona:', rpcError ? '❌ NÃO' : '✅ SIM');
console.log('===================================================================');

