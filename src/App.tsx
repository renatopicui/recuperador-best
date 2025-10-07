import { useEffect, useState } from 'react';
import { supabase } from './services/supabaseService';
import AuthForm from './components/AuthForm';
import Dashboard from './components/Dashboard';
import AdminDashboard from './components/AdminDashboard';
import Checkout from './components/Checkout';
import SupabaseTest from './components/SupabaseTest';
import { User } from '@supabase/supabase-js';

function App() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [isCheckoutPage, setIsCheckoutPage] = useState(false);
  const [showSupabaseTest, setShowSupabaseTest] = useState(false);

  useEffect(() => {
    const path = window.location.pathname;
    setIsCheckoutPage(path.startsWith('/checkout/'));
    setShowSupabaseTest(path === '/supabase-test');

    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null);
      setLoading(false);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
    });

    return () => subscription.unsubscribe();
  }, []);

  if (isCheckoutPage) {
    return <Checkout />;
  }

  if (showSupabaseTest) {
    return <SupabaseTest />;
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 flex items-center justify-center">
        <div className="text-white text-xl">Carregando...</div>
      </div>
    );
  }

  if (!user) {
    return <AuthForm />;
  }

  const isAdmin = user.email === 'adm@bestfybr.com.br';

  return isAdmin ? <AdminDashboard user={user} /> : <Dashboard user={user} />;
}

export default App;
