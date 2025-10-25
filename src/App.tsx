import { useEffect, useState } from 'react';
import { supabase } from './services/supabaseService';
import AuthForm from './components/AuthForm';
import DashboardLayout from './components/DashboardLayout';
import AdminDashboard from './components/AdminDashboard';
import Checkout from './components/Checkout';
import ThankYou from './components/ThankYou';
import SupabaseTest from './components/SupabaseTest';
import { User } from '@supabase/supabase-js';

function App() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [isCheckoutPage, setIsCheckoutPage] = useState(false);
  const [isThankYouPage, setIsThankYouPage] = useState(false);
  const [showSupabaseTest, setShowSupabaseTest] = useState(false);

  useEffect(() => {
    const path = window.location.pathname;
    setIsCheckoutPage(path.startsWith('/checkout/'));
    setIsThankYouPage(path.startsWith('/obrigado/'));
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

  if (isThankYouPage) {
    return <ThankYou />;
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

  return isAdmin ? <AdminDashboard user={user} /> : <DashboardLayout user={user} />;
}

export default App;
