import { useState } from 'react';
import { User } from '@supabase/supabase-js';
import { Home, Settings as SettingsIcon, LogOut } from 'lucide-react';
import { authService } from '../services/authService';
import Dashboard from './Dashboard';
import Settings from './Settings';

interface DashboardLayoutProps {
  user: User;
}

type View = 'dashboard' | 'settings';

export default function DashboardLayout({ user }: DashboardLayoutProps) {
  const [currentView, setCurrentView] = useState<View>('dashboard');

  const handleSignOut = async () => {
    await authService.signOut();
  };

  const menuItems = [
    { id: 'dashboard' as View, label: 'Painel', icon: Home },
    { id: 'settings' as View, label: 'Configurações', icon: SettingsIcon },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
      {/* Top Navigation Bar */}
      <div className="bg-gray-800/50 backdrop-blur-sm border-b border-gray-700">
        <div className="container mx-auto px-4">
          <div className="flex items-center justify-between h-16">
            {/* Logo/Brand */}
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-lg">R</span>
              </div>
              <span className="text-white font-semibold text-lg">Recuperador</span>
            </div>

            {/* Navigation Menu */}
            <nav className="flex items-center gap-1">
              {menuItems.map((item) => {
                const Icon = item.icon;
                const isActive = currentView === item.id;
                
                return (
                  <button
                    key={item.id}
                    onClick={() => setCurrentView(item.id)}
                    className={`flex items-center gap-2 px-4 py-2 rounded-lg transition-colors ${
                      isActive
                        ? 'bg-blue-600 text-white'
                        : 'text-gray-300 hover:bg-gray-700/50 hover:text-white'
                    }`}
                  >
                    <Icon className="w-5 h-5" />
                    <span className="font-medium">{item.label}</span>
                  </button>
                );
              })}
            </nav>

            {/* User Info & Logout */}
            <div className="flex items-center gap-4">
              <div className="text-right">
                <div className="text-sm text-gray-400">Olá,</div>
                <div className="text-white font-medium">{user.email}</div>
              </div>
              <button
                onClick={handleSignOut}
                className="flex items-center gap-2 px-4 py-2 bg-red-600/10 hover:bg-red-600/20 text-red-400 rounded-lg transition-colors"
              >
                <LogOut className="w-5 h-5" />
                <span className="font-medium">Sair</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="container mx-auto px-4 py-8">
        {currentView === 'dashboard' && <Dashboard user={user} />}
        {currentView === 'settings' && <Settings />}
      </div>
    </div>
  );
}

