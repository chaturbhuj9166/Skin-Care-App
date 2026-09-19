import { useState } from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useSocketEvent } from '../lib/socket';
import {
  Bell,
  BellRing,
  BriefcaseMedical,
  ChevronRight,
  LayoutDashboard,
  LifeBuoy,
  LogOut,
  Menu,
  Search,
  Settings,
  ShieldCheck,
  Stethoscope,
  Users,
  Video,
  Workflow,
  X,
} from 'lucide-react';
import { useAuthStore } from '../store/authStore';
import { disconnectSocket } from '../lib/socket';
import ToastContainer from './ToastContainer';

const NAV = [
  { to: '/', label: 'Dashboard', end: true, icon: LayoutDashboard },
  { to: '/cases', label: 'Cases', icon: BriefcaseMedical },
  { to: '/question-builder', label: 'Question Builder', icon: Workflow },
  { to: '/doctors', label: 'Doctors', icon: Stethoscope },
  { to: '/users', label: 'Users', icon: Users },
  { to: '/tickets', label: 'Tickets', icon: LifeBuoy },
  { to: '/video-calls', label: 'Video calls', icon: Video },
  { to: '/notifications', label: 'Notifications', icon: BellRing },
  { to: '/settings', label: 'Settings', icon: Settings },
];

export default function AppShell() {
  const admin = useAuthStore((s) => s.admin);
  const logout = useAuthStore((s) => s.logout);
  const navigate = useNavigate();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [searchValue, setSearchValue] = useState('');
  const [unseen, setUnseen] = useState(0);

  useSocketEvent(['case_assigned', 'notification', 'new_message'], () => setUnseen((c) => c + 1));

  function handleLogout() {
    disconnectSocket();
    logout();
    navigate('/login');
  }

  function handleSearch(e) {
    e.preventDefault();
    const query = searchValue.trim();
    navigate(query ? `/cases?search=${encodeURIComponent(query)}` : '/cases');
  }

  function handleBellClick() {
    setUnseen(0);
    navigate('/notifications');
  }

  const initials = (admin?.name || 'A')
    .split(' ')
    .map((p) => p[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();

  const sidebarContent = (
    <>
      <div className="mb-6 flex items-center justify-between gap-3 lg:mb-8">
        <div className="flex items-center gap-3">
          <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-brand-teal/10 text-brand-teal">
            <Stethoscope className="h-5 w-5" />
          </div>
          <div>
            <p className="text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-500">SkinCare</p>
            <h2 className="text-base font-semibold text-slate-900">Admin Console</h2>
          </div>
        </div>
        <button
          type="button"
          onClick={() => setMobileOpen(false)}
          className="rounded-lg p-2 text-slate-500 hover:bg-slate-100 lg:hidden"
          aria-label="Close navigation"
        >
          <X className="h-5 w-5" />
        </button>
      </div>

      <nav className="flex-1 space-y-1.5 overflow-y-auto">
        {NAV.map(({ to, label, end, icon: Icon }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            onClick={() => setMobileOpen(false)}
            className={({ isActive }) =>
              `group flex w-full items-center justify-between rounded-xl px-3 py-2.5 text-sm font-medium transition-all duration-200 ${
                isActive ? 'bg-brand-teal text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
              }`
            }
          >
            {({ isActive }) => (
              <>
                <span className="flex items-center gap-3">
                  <span className={`flex h-8 w-8 items-center justify-center rounded-lg ${isActive ? 'bg-white/15' : 'bg-slate-100 text-slate-500'}`}>
                    <Icon className="h-4 w-4" />
                  </span>
                  {label}
                </span>
                <ChevronRight className={`h-4 w-4 transition-transform ${isActive ? 'text-white' : 'text-slate-300 group-hover:translate-x-0.5'}`} />
              </>
            )}
          </NavLink>
        ))}
      </nav>

      <div className="mt-6 rounded-xl border border-brand-teal/10 bg-brand-teal/5 p-3.5">
        <p className="text-[10px] font-semibold uppercase tracking-[0.15em] text-brand-teal">Status</p>
        <div className="mt-2 flex items-center justify-between gap-2">
          <span className="text-sm font-medium text-slate-700">System health</span>
          <span className="inline-flex items-center gap-1 rounded-full bg-green-100 px-2 py-1 text-[10px] font-medium text-green-700">
            <span className="h-2 w-2 rounded-full bg-green-500" />
            Healthy
          </span>
        </div>
      </div>
    </>
  );

  return (
    <div className="flex min-h-screen bg-slate-50">
      <button
        type="button"
        onClick={() => setMobileOpen((v) => !v)}
        className="fixed left-4 top-4 z-50 inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white p-2.5 text-slate-700 shadow-sm lg:hidden"
        aria-label="Toggle navigation"
      >
        <Menu className="h-5 w-5" />
      </button>

      {mobileOpen && (
        <button
          type="button"
          aria-label="Close mobile navigation overlay"
          onClick={() => setMobileOpen(false)}
          className="fixed inset-0 z-40 bg-slate-900/40 lg:hidden"
        />
      )}

      <aside
        className={`fixed left-0 top-0 z-50 flex h-screen w-72 flex-col overflow-hidden border-r border-slate-200 bg-white p-5 transition-transform duration-200 lg:sticky lg:translate-x-0 ${
          mobileOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        {sidebarContent}
      </aside>

      <div className="flex flex-1 flex-col">
        <header className="sticky top-0 z-30 border-b border-slate-200 bg-white/85 px-4 py-4 backdrop-blur-sm sm:px-6 lg:px-8">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <form onSubmit={handleSearch} className="flex flex-1 items-center gap-3 rounded-xl border border-slate-200 bg-slate-50 px-3 py-2.5 lg:max-w-sm">
              <Search className="h-4 w-4 flex-shrink-0 text-slate-400" />
              <input
                type="text"
                value={searchValue}
                onChange={(e) => setSearchValue(e.target.value)}
                placeholder="Search cases by name or phone…"
                className="w-full bg-transparent text-sm text-slate-700 placeholder:text-slate-400 focus:outline-none"
              />
            </form>

            <div className="flex items-center gap-3 self-end lg:self-auto">
              <div className="hidden items-center gap-2 rounded-full border border-green-200 bg-green-50 px-3 py-1.5 text-xs font-medium text-green-700 sm:inline-flex">
                <ShieldCheck className="h-3.5 w-3.5" />
                System healthy
              </div>

              <button
                type="button"
                onClick={handleBellClick}
                title="Notifications"
                className="relative flex h-11 w-11 items-center justify-center rounded-xl border border-slate-200 bg-slate-50 text-slate-600 transition hover:border-slate-300 hover:bg-white"
              >
                <Bell className="h-4 w-4" />
                {unseen > 0 && (
                  <span className="absolute right-1.5 top-1.5 flex h-4 min-w-[16px] items-center justify-center rounded-full bg-brand-amber px-1 text-[9px] font-bold text-white ring-2 ring-white">
                    {unseen > 9 ? '9+' : unseen}
                  </span>
                )}
              </button>

              <div className="flex items-center gap-3 rounded-xl border border-slate-200 bg-slate-50 px-2.5 py-2">
                <div className="flex h-10 w-10 items-center justify-center rounded-full bg-brand-teal text-sm font-semibold text-white">
                  {initials}
                </div>
                <div className="hidden text-left sm:block">
                  <p className="text-sm font-semibold text-slate-900">{admin?.name || 'Admin'}</p>
                  <p className="text-[11px] text-slate-500">Super Admin</p>
                </div>
              </div>

              <button
                onClick={handleLogout}
                title="Logout"
                className="flex h-11 w-11 items-center justify-center rounded-xl border border-slate-200 bg-slate-50 text-slate-600 transition hover:border-red-200 hover:bg-red-50 hover:text-red-600"
              >
                <LogOut className="h-4 w-4" />
              </button>
            </div>
          </div>
        </header>
        <main className="flex-1 p-4 sm:p-6 lg:p-8">
          <Outlet />
        </main>
      </div>
      <ToastContainer />
    </div>
  );
}
