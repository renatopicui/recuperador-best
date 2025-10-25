import { supabase } from './supabaseService';

export const authService = {
  async signUp(email: string, password: string, fullName: string, phone: string) {
    console.log('📝 [AuthService] Iniciando cadastro...');
    console.log('📝 [AuthService] Email:', email);
    console.log('📝 [AuthService] Nome:', fullName);
    console.log('📝 [AuthService] Telefone:', phone);
    
    const signUpPayload = {
      email,
      password,
      options: {
        data: {
          full_name: fullName,
          phone: phone,
        }
      }
    };
    
    console.log('📦 [AuthService] Payload que será enviado ao Supabase:');
    console.log('📦 [AuthService]', JSON.stringify(signUpPayload.options.data, null, 2));
    
    // Criar usuário no auth.users com metadata
    // O trigger do banco criará automaticamente o perfil
    const { data, error } = await supabase.auth.signUp(signUpPayload);

    if (error) {
      console.error('❌ [AuthService] Erro ao criar usuário:', error);
      throw error;
    }

    console.log('✅ [AuthService] Usuário criado com sucesso!');
    console.log('✅ [AuthService] User ID:', data.user?.id);
    console.log('✅ [AuthService] Email:', data.user?.email);
    console.log('📊 [AuthService] Metadata salvo:', data.user?.user_metadata);
    console.log('🔥 [AuthService] Trigger do banco salvará em users_list automaticamente');

    return data;
  },

  async signIn(email: string, password: string) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) throw error;
    return data;
  },

  async signOut() {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  },

  async getSession() {
    const { data: { session }, error } = await supabase.auth.getSession();
    if (error) throw error;
    return session;
  },
};
