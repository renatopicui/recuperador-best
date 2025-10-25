// ============================================
// TESTE NO CONSOLE DO NAVEGADOR
// Abra F12, cole este código e pressione Enter
// ============================================

(async () => {
  console.log('🔍 TESTE: Verificando sistema de redirecionamento...\n');
  
  try {
    // 1. Pegar URL atual
    const path = window.location.pathname;
    const slug = path.split('/checkout/')[1];
    
    console.log('1️⃣ Checkout atual:', slug);
    
    if (!slug) {
      console.error('❌ Você não está em uma página de checkout!');
      return;
    }
    
    // 2. Importar função do serviço
    const { checkoutService } = await import('/src/services/checkoutService.ts');
    
    console.log('2️⃣ Buscando dados do banco...');
    
    // 3. Buscar dados atualizados
    const data = await checkoutService.getCheckoutBySlug(slug);
    
    console.log('3️⃣ Dados retornados:');
    console.log('   - checkout_slug:', data.checkout_slug);
    console.log('   - payment_status:', data.payment_status);
    console.log('   - thank_you_slug:', data.thank_you_slug);
    console.log('\n');
    
    // 4. Verificar status
    if (data.payment_status === 'paid') {
      console.log('✅ PAGAMENTO ESTÁ PAGO!');
      
      if (data.thank_you_slug) {
        console.log('✅ thank_you_slug encontrado:', data.thank_you_slug);
        console.log('🚀 Redirecionando para página de obrigado...\n');
        
        const url = `/obrigado/${data.thank_you_slug}`;
        console.log('📍 URL:', window.location.origin + url);
        
        setTimeout(() => {
          window.location.href = url;
        }, 1000);
      } else {
        console.error('❌ thank_you_slug NÃO encontrado!');
        console.log('⚠️ Execute FIX-DEFINITIVO.sql no Supabase');
      }
    } else {
      console.log('⏳ Pagamento ainda pendente');
      console.log('   Status atual:', data.payment_status);
      console.log('\n');
      console.log('💡 Para testar, execute no Supabase:');
      console.log(`   UPDATE payments SET status = 'paid'`);
      console.log(`   WHERE id = '${data.payment_id}';`);
    }
    
  } catch (error) {
    console.error('\n❌ ERRO:', error.message);
    console.log('\n');
    console.log('🔧 Possíveis causas:');
    console.log('1. Função get_checkout_by_slug não existe no banco');
    console.log('2. Execute FIX-DEFINITIVO.sql no Supabase');
    console.log('3. Verifique se o checkout existe');
  }
})();

