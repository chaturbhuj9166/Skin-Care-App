import { useState } from 'react';
import { useNavigate, Navigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { HeartPulse, LockKeyhole, Mail, ShieldCheck } from 'lucide-react';
import { api, apiErrorMessage } from '../lib/api';
import { useAuthStore } from '../store/authStore';
import Button from '../components/Button';
import Field from '../components/Field';
import { ErrorMessage } from '../components/Feedback';

export default function Login() {
  const token = useAuthStore((s) => s.token);
  const login = useAuthStore((s) => s.login);
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  if (token) return <Navigate to="/" replace />;

  async function handleSubmit(e) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const { data } = await api.post('/auth/admin/login', { email, password });
      login(data.token, data.admin);
      navigate('/');
    } catch (err) {
      setError(apiErrorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div
      className="flex min-h-screen items-center justify-center p-6"
      style={{ background: 'radial-gradient(circle at top, #e6fffb, #f8fafc 45%, #eef2ff)' }}
    >
      <motion.div
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.45, ease: 'easeOut' }}
        className="grid w-full max-w-5xl overflow-hidden rounded-[28px] border border-slate-200 bg-white shadow-[0_30px_80px_rgba(15,23,42,0.12)] lg:grid-cols-2"
      >
        <div className="flex flex-col justify-between bg-brand-teal p-8 text-white lg:p-10">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.2em] text-teal-50">
              <HeartPulse className="h-3.5 w-3.5" />
              SkinCare
            </div>
            <h1 className="mt-8 text-4xl font-heading font-bold tracking-tight">Welcome back</h1>
            <p className="mt-4 max-w-sm text-sm text-teal-50/90">
              Manage consultations, doctors, and cases from one secure clinical operations dashboard.
            </p>
          </div>

          <div className="mt-10 rounded-2xl border border-white/15 bg-white/5 p-5 backdrop-blur-sm">
            <div className="flex items-center gap-3">
              <div className="flex h-11 w-11 items-center justify-center rounded-full bg-white/10">
                <ShieldCheck className="h-5 w-5" />
              </div>
              <div>
                <p className="text-xs uppercase tracking-[0.18em] text-teal-100">Secure access</p>
                <p className="text-lg font-semibold">Protected admin portal</p>
              </div>
            </div>
          </div>
        </div>

        <div className="flex items-center justify-center p-8 lg:p-10">
          <div className="w-full max-w-md">
            <div className="mb-8">
              <p className="text-sm font-semibold uppercase tracking-[0.2em] text-brand-teal">Admin sign in</p>
              <h2 className="mt-2 text-3xl font-heading font-bold text-slate-900">Log in to your account</h2>
            </div>

            <form onSubmit={handleSubmit} className="space-y-5">
              <Field label="Email address">
                <div className="flex items-center gap-3 rounded-xl border border-slate-200 bg-slate-50 px-3 py-2.5 focus-within:border-brand-teal focus-within:bg-white">
                  <Mail className="h-4 w-4 text-slate-400" />
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="admin@skincareapp.com"
                    className="w-full border-0 bg-transparent text-sm text-slate-800 outline-none placeholder:text-slate-400"
                  />
                </div>
              </Field>

              <Field label="Password">
                <div className="flex items-center gap-3 rounded-xl border border-slate-200 bg-slate-50 px-3 py-2.5 focus-within:border-brand-teal focus-within:bg-white">
                  <LockKeyhole className="h-4 w-4 text-slate-400" />
                  <input
                    type="password"
                    required
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="••••••••"
                    className="w-full border-0 bg-transparent text-sm text-slate-800 outline-none placeholder:text-slate-400"
                  />
                </div>
              </Field>

              {error && <ErrorMessage message={error} />}

              <Button type="submit" className="w-full" disabled={loading}>
                {loading ? 'Signing in…' : 'Sign in'}
              </Button>
            </form>
          </div>
        </div>
      </motion.div>
    </div>
  );
}
