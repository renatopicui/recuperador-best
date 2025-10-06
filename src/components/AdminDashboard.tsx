import { useEffect, useState } from 'react';
import { User } from '@supabase/supabase-js';
import { authService } from '../services/authService';
import { adminService, UserListItem } from '../services/adminService';
import { Payment } from '../types/bestfy';
import { LogOut, Users, DollarSign, CheckCircle2, Clock, XCircle } from 'lucide-react';

interface AdminDashboardProps {
  user: User;
}

export default function AdminDashboard({ user }: AdminDashboardProps) {
  const [users, setUsers] = useState<UserListItem[]>([]);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [usersData, paymentsData] = await Promise.all([
        adminService.getAllUsers(),
        adminService.getAllPayments(),
      ]);
      setUsers(usersData);
      setPayments(paymentsData);
    } catch (error) {
      console.error('Erro ao carregar dados:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    await authService.signOut();
  };

  const stats = {
    totalUsers: users.length,
    totalPayments: payments.length,
    paid: payments.filter(p => p.status === 'paid').length,
    paidAmount: payments.filter(p => p.status === 'paid').reduce((sum, p) => sum + Number(p.amount), 0),
    pending: payments.filter(p => p.status === 'waiting_payment').length,
    recovered: payments.filter(p => p.converted_from_recovery).length,
  };

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL',
    }).format(value / 100);
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 flex items-center justify-center">
        <div className="text-white text-xl">Carregando...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 p-6">
      <div className="max-w-7xl mx-auto">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold text-white mb-2">Painel Administrativo</h1>
            <p className="text-gray-400">{user.email}</p>
          </div>
          <button
            onClick={handleLogout}
            className="flex items-center gap-2 bg-gray-700 hover:bg-gray-600 text-white px-4 py-2 rounded-lg transition-colors"
          >
            <LogOut className="w-4 h-4" />
            Sair
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4">
              <div className="bg-blue-500/20 p-3 rounded-lg">
                <Users className="w-6 h-6 text-blue-400" />
              </div>
              <div>
                <p className="text-gray-400 text-sm">Total de Usuários</p>
                <p className="text-2xl font-bold text-white">{stats.totalUsers}</p>
              </div>
            </div>
          </div>

          <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4">
              <div className="bg-green-500/20 p-3 rounded-lg">
                <CheckCircle2 className="w-6 h-6 text-green-400" />
              </div>
              <div>
                <p className="text-gray-400 text-sm">Pagamentos Pagos</p>
                <p className="text-2xl font-bold text-white">{stats.paid}</p>
                <p className="text-green-400 text-sm">{formatCurrency(stats.paidAmount)}</p>
              </div>
            </div>
          </div>

          <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4">
              <div className="bg-yellow-500/20 p-3 rounded-lg">
                <Clock className="w-6 h-6 text-yellow-400" />
              </div>
              <div>
                <p className="text-gray-400 text-sm">Pendentes</p>
                <p className="text-2xl font-bold text-white">{stats.pending}</p>
              </div>
            </div>
          </div>

          <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4">
              <div className="bg-purple-500/20 p-3 rounded-lg">
                <DollarSign className="w-6 h-6 text-purple-400" />
              </div>
              <div>
                <p className="text-gray-400 text-sm">Recuperados</p>
                <p className="text-2xl font-bold text-white">{stats.recovered}</p>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-gray-800/50 backdrop-blur-sm border border-gray-700 rounded-xl p-6 mb-6">
          <h2 className="text-xl font-bold text-white mb-4">Usuários Cadastrados</h2>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-700">
                  <th className="text-left text-gray-400 font-medium py-3 px-4">Email</th>
                  <th className="text-left text-gray-400 font-medium py-3 px-4">Data de Cadastro</th>
                  <th className="text-left text-gray-400 font-medium py-3 px-4">Pagamentos</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => {
                  const userPayments = payments.filter(p => p.user_id === u.id);
                  return (
                    <tr key={u.id} className="border-b border-gray-700/50 hover:bg-gray-700/30 transition-colors">
                      <td className="py-4 px-4 text-white">{u.email}</td>
                      <td className="py-4 px-4 text-gray-400">
                        {new Date(u.created_at).toLocaleDateString('pt-BR')}
                      </td>
                      <td className="py-4 px-4 text-gray-300">{userPayments.length}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>

      </div>
    </div>
  );
}
