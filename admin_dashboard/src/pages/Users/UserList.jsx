import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../../lib/api';
import { useApiQuery } from '../../hooks/useApiQuery';
import { useDebouncedValue } from '../../hooks/useDebouncedValue';
import Card from '../../components/Card';
import Table from '../../components/Table';
import Button from '../../components/Button';
import { TextInput } from '../../components/Field';
import { Loading, ErrorMessage } from '../../components/Feedback';

export default function UserList() {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const debouncedSearch = useDebouncedValue(search);
  const { data, loading, error, refetch } = useApiQuery(
    () => api.get('/admin/users', { params: { page, limit: 20, ...(debouncedSearch && { search: debouncedSearch }) } }),
    [debouncedSearch, page],
  );

  async function toggleBlock(user, e) {
    e.stopPropagation();
    await api.put(`/admin/users/${user.id}`, { isBlocked: !user.isBlocked });
    refetch();
  }

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold text-slate-800">Users</h1>
      <Card>
        <TextInput
          className="mb-4"
          placeholder="Search by name, phone or email"
          value={search}
          onChange={(e) => { setPage(1); setSearch(e.target.value); }}
        />
        {loading && <Loading />}
        {error && <ErrorMessage message={error} />}
        {data && (
          <>
            <Table
              rowKey={(row) => row.id}
              onRowClick={(row) => navigate(`/users/${row.id}`)}
              columns={[
                { key: 'name', header: 'Name', render: (r) => (
                  <div className="flex items-center gap-3">
                    {r.avatar ? (
                      <img src={r.avatar} alt={r.name} className="h-9 w-9 rounded-full object-cover" />
                    ) : (
                      <div className="flex h-9 w-9 items-center justify-center rounded-full bg-brand-teal/10 text-xs font-semibold text-brand-teal">
                        {r.name?.slice(0, 2).toUpperCase()}
                      </div>
                    )}
                    <span className="font-medium text-slate-700">{r.name}</span>
                  </div>
                ) },
                { key: 'phone', header: 'Phone' },
                { key: 'email', header: 'Email', render: (r) => r.email || '—' },
                { key: 'cases', header: 'Cases', render: (r) => r._count?.cases ?? 0 },
                { key: 'joined', header: 'Joined', render: (r) => new Date(r.createdAt).toLocaleDateString() },
                { key: 'status', header: 'Status', render: (r) => (r.isBlocked ? <span className="text-red-600">Blocked</span> : <span className="text-green-600">Active</span>) },
                { key: 'actions', header: '', render: (r) => (
                  <Button variant={r.isBlocked ? 'secondary' : 'danger'} onClick={(e) => toggleBlock(r, e)}>
                    {r.isBlocked ? 'Unblock' : 'Block'}
                  </Button>
                ) },
              ]}
              rows={data.data}
            />
            <div className="mt-4 flex items-center justify-between text-sm text-slate-500">
              <span>Page {data.page} of {data.totalPages || 1} · {data.total} users</span>
              <div className="flex gap-2">
                <Button variant="secondary" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Previous</Button>
                <Button variant="secondary" disabled={page >= data.totalPages} onClick={() => setPage((p) => p + 1)}>Next</Button>
              </div>
            </div>
          </>
        )}
      </Card>
    </div>
  );
}
