import { useParams, Link, useNavigate } from 'react-router-dom';
import { api } from '../../lib/api';
import { useApiQuery } from '../../hooks/useApiQuery';
import Card from '../../components/Card';
import Table from '../../components/Table';
import Button from '../../components/Button';
import StatusBadge from '../../components/StatusBadge';
import { Loading, ErrorMessage } from '../../components/Feedback';

export default function UserDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { data, loading, error, refetch } = useApiQuery(() => api.get(`/admin/users/${id}`), [id]);

  if (loading) return <Loading />;
  if (error) return <ErrorMessage message={error} />;

  const { user, cases } = data;

  async function toggleBlock() {
    await api.put(`/admin/users/${id}`, { isBlocked: !user.isBlocked });
    refetch();
  }

  return (
    <div className="flex flex-col gap-4">
      <Link to="/users" className="text-sm text-brand-teal hover:underline">← Back to users</Link>

      <Card>
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold text-slate-800">{user.name}</h1>
            <div className="text-sm text-slate-500">{user.phone} · {user.email || 'no email'}</div>
            <div className="text-sm text-slate-500">{user.gender || '—'}, {user.age || '—'} years</div>
          </div>
          <Button variant={user.isBlocked ? 'secondary' : 'danger'} onClick={toggleBlock}>
            {user.isBlocked ? 'Unblock user' : 'Block user'}
          </Button>
        </div>
      </Card>

      <Card>
        <h3 className="mb-3 text-sm font-semibold text-slate-600">Case history</h3>
        <Table
          rowKey={(row) => row.id}
          onRowClick={(row) => navigate(`/cases/${row.id}`)}
          columns={[
            { key: 'doctor', header: 'Doctor', render: (r) => r.doctor?.name || '—' },
            { key: 'status', header: 'Status', render: (r) => <StatusBadge status={r.status} /> },
            { key: 'createdAt', header: 'Created', render: (r) => new Date(r.createdAt).toLocaleDateString() },
          ]}
          rows={cases}
        />
      </Card>
    </div>
  );
}
