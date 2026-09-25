import { useState } from 'react';
import { Link } from 'react-router-dom';
import { LineChart, Line, BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { Clock, FileText, Stethoscope, UserPlus, Users } from 'lucide-react';
import { api } from '../lib/api';
import { useApiQuery } from '../hooks/useApiQuery';
import { useSocketEvent } from '../lib/socket';
import Card from '../components/Card';
import Table from '../components/Table';
import StatusBadge from '../components/StatusBadge';
import AssignDoctorModal from '../components/AssignDoctorModal';
import { Loading, ErrorMessage } from '../components/Feedback';

const STATUS_COLORS = { PENDING: '#F59E0B', ASSIGNED: '#3B82F6', IN_REVIEW: '#6366F1', SOLVED: '#22C55E', CLOSED: '#94A3B8' };

const STAT_TONES = {
  teal: { icon: 'bg-brand-teal/10 text-brand-teal' },
  green: { icon: 'bg-green-100 text-green-600' },
  amber: { icon: 'bg-amber-100 text-amber-600' },
  rose: { icon: 'bg-rose-100 text-rose-600' },
};

function StatCard({ label, value, icon: Icon, tone = 'teal' }) {
  return (
    <Card>
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-slate-500">{label}</p>
          <h3 className="mt-3 text-3xl font-bold text-slate-900">{value ?? '—'}</h3>
        </div>
        <div className={`flex h-12 w-12 items-center justify-center rounded-2xl ${STAT_TONES[tone].icon}`}>
          <Icon className="h-5 w-5" />
        </div>
      </div>
    </Card>
  );
}

export default function Dashboard() {
  const { data, loading, error, refetch } = useApiQuery(() => api.get('/admin/analytics'), []);
  const { data: recentCases, refetch: refetchCases } = useApiQuery(() => api.get('/admin/cases', { params: { limit: 5 } }), []);
  const { data: recentTickets, refetch: refetchTickets } = useApiQuery(() => api.get('/admin/tickets', { params: { limit: 5 } }), []);
  const [assigningCaseId, setAssigningCaseId] = useState(null);

  useSocketEvent(['case_assigned', 'case_status_changed', 'notification', 'new_message'], refetch);
  useSocketEvent(['case_assigned', 'case_status_changed'], refetchCases);
  useSocketEvent(['notification'], refetchTickets);

  if (loading) return <Loading label="Loading analytics…" />;
  if (error) return <ErrorMessage message={error} />;

  const statusData = Object.entries(data.statusDistribution || {}).map(([status, count]) => ({ status, count }));

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-heading font-bold tracking-tight text-slate-900">Dashboard Overview</h1>
          <p className="mt-1 text-sm text-slate-500">Real-time platform metrics, analytics, and active patient cases.</p>
        </div>
        <div className="inline-flex items-center gap-2 rounded-full border border-green-200 bg-green-50 px-3 py-1.5 text-xs font-medium text-green-700">
          <span className="h-2 w-2 rounded-full bg-green-500" />
          System live &amp; connected
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Total users" value={data.totals.totalUsers} icon={Users} tone="teal" />
        <StatCard label="Total doctors" value={data.totals.totalDoctors} icon={Stethoscope} tone="green" />
        <StatCard label="Total cases" value={data.totals.totalCases} icon={FileText} tone="amber" />
        <StatCard label="Pending cases" value={data.totals.pendingCases} icon={Clock} tone="rose" />
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <h3 className="mb-4 text-lg font-semibold text-slate-900">Cases per month</h3>
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={data.casesPerMonth}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
              <XAxis dataKey="month" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 12 }} allowDecimals={false} />
              <Tooltip />
              <Bar dataKey="count" fill="#0A7C6E" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </Card>

        <Card>
          <h3 className="mb-4 text-lg font-semibold text-slate-900">Case status</h3>
          <ResponsiveContainer width="100%" height={260}>
            <PieChart>
              <Pie data={statusData} dataKey="count" nameKey="status" innerRadius={50} outerRadius={80} paddingAngle={2}>
                {statusData.map((entry) => (
                  <Cell key={entry.status} fill={STATUS_COLORS[entry.status] || '#CBD5E1'} />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </Card>
      </div>

      <Card>
        <h3 className="mb-4 text-lg font-semibold text-slate-900">New users per week</h3>
        <ResponsiveContainer width="100%" height={220}>
          <LineChart data={data.weeklyNewUsers}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
            <XAxis dataKey="week" tick={{ fontSize: 12 }} />
            <YAxis tick={{ fontSize: 12 }} allowDecimals={false} />
            <Tooltip />
            <Line type="monotone" dataKey="count" stroke="#22C55E" strokeWidth={2} dot={false} />
          </LineChart>
        </ResponsiveContainer>
      </Card>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card>
          <div className="mb-4 flex items-center justify-between gap-3">
            <h3 className="text-lg font-semibold text-slate-900">Recent cases</h3>
            <span className="rounded-full bg-brand-teal/10 px-2 py-1 text-[10px] font-medium uppercase tracking-[0.15em] text-brand-teal">Live</span>
          </div>
          <Table
            rowKey={(row) => row.id}
            emptyMessage="No cases yet."
            columns={[
              { key: 'id', header: 'Case ID', render: (c) => (
                <Link to={`/cases/${c.id}`} className="font-mono text-xs text-brand-teal hover:underline">SKC-{c.id.slice(0, 6).toUpperCase()}</Link>
              ) },
              { key: 'user', header: 'User', render: (c) => c.user?.name || '—' },
              { key: 'createdAt', header: 'Submitted', render: (c) => new Date(c.createdAt).toLocaleDateString() },
              { key: 'status', header: 'Status', render: (c) => <StatusBadge status={c.status} /> },
              { key: 'assign', header: '', render: (c) => (!c.doctorId && !['SOLVED', 'CLOSED'].includes(c.status) ? (
                <button
                  type="button"
                  onClick={() => setAssigningCaseId(c.id)}
                  className="inline-flex items-center gap-1 rounded-full border border-brand-teal/30 bg-brand-teal/10 px-2.5 py-1 text-[11px] font-semibold text-brand-teal transition hover:bg-brand-teal/20"
                >
                  <UserPlus className="h-3.5 w-3.5" />
                  Assign
                </button>
              ) : null) },
            ]}
            rows={recentCases?.data || []}
          />
        </Card>
        <Card>
          <div className="mb-4 flex items-center justify-between gap-3">
            <h3 className="text-lg font-semibold text-slate-900">Recent tickets</h3>
            <span className="rounded-full bg-brand-teal/10 px-2 py-1 text-[10px] font-medium uppercase tracking-[0.15em] text-brand-teal">Live</span>
          </div>
          <Table
            rowKey={(row) => row.id}
            emptyMessage="No tickets yet."
            columns={[
              { key: 'user', header: 'User', render: (t) => t.user?.name || '—' },
              { key: 'subject', header: 'Subject' },
              { key: 'priority', header: 'Priority', render: (t) => <StatusBadge status={t.priority} /> },
              { key: 'status', header: 'Status', render: (t) => <StatusBadge status={t.status} /> },
              { key: 'createdAt', header: 'Date', render: (t) => new Date(t.createdAt).toLocaleDateString() },
            ]}
            rows={recentTickets?.data || []}
          />
        </Card>
      </div>

      <AssignDoctorModal
        caseId={assigningCaseId}
        open={!!assigningCaseId}
        onClose={() => setAssigningCaseId(null)}
        onAssigned={refetchCases}
      />
    </div>
  );
}
