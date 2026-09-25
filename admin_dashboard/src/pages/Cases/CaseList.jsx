import { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { UserPlus } from 'lucide-react';
import { api, apiErrorMessage } from '../../lib/api';
import { useApiQuery } from '../../hooks/useApiQuery';
import { useDebouncedValue } from '../../hooks/useDebouncedValue';
import { useSocketEvent } from '../../lib/socket';
import { toastError } from '../../store/toastStore';
import Card from '../../components/Card';
import Table from '../../components/Table';
import Button from '../../components/Button';
import StatusBadge from '../../components/StatusBadge';
import AssignDoctorModal from '../../components/AssignDoctorModal';
import { TextInput, Select } from '../../components/Field';
import { Loading, ErrorMessage } from '../../components/Feedback';

const STATUSES = ['PENDING', 'ASSIGNED', 'IN_REVIEW', 'SOLVED', 'CLOSED'];

export default function CaseList() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [search, setSearch] = useState(searchParams.get('search') || '');
  const [status, setStatus] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [page, setPage] = useState(1);
  const [assigningCaseId, setAssigningCaseId] = useState(null);
  const [exporting, setExporting] = useState(false);

  const debouncedSearch = useDebouncedValue(search);
  const filters = { ...(debouncedSearch && { search: debouncedSearch }), ...(status && { status }), ...(from && { from }), ...(to && { to }) };
  const { data, loading, error, refetch } = useApiQuery(
    () => api.get('/admin/cases', { params: { page, limit: 20, ...filters } }),
    [debouncedSearch, status, from, to, page],
  );

  useSocketEvent(['case_assigned', 'case_status_changed', 'notification'], refetch);

  async function exportCsv() {
    setExporting(true);
    try {
      // The export endpoint is token-protected, so it has to go through the
      // axios instance (window.open sends no Authorization header) and the
      // returned blob is saved via a temporary object URL.
      const response = await api.get('/admin/cases/export', { params: filters, responseType: 'blob' });
      const url = URL.createObjectURL(response.data);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'cases.csv';
      link.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      toastError(apiErrorMessage(err));
    } finally {
      setExporting(false);
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-slate-800">Cases</h1>
        <Button variant="secondary" onClick={exportCsv} disabled={exporting}>{exporting ? 'Exporting…' : 'Export CSV'}</Button>
      </div>

      <Card>
        <div className="mb-4 grid grid-cols-1 gap-3 sm:grid-cols-4">
          <TextInput placeholder="Search by user name/phone" value={search} onChange={(e) => { setPage(1); setSearch(e.target.value); }} />
          <Select value={status} onChange={(e) => { setPage(1); setStatus(e.target.value); }}>
            <option value="">All statuses</option>
            {STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
          </Select>
          <TextInput type="date" value={from} onChange={(e) => { setPage(1); setFrom(e.target.value); }} />
          <TextInput type="date" value={to} onChange={(e) => { setPage(1); setTo(e.target.value); }} />
        </div>

        {loading && <Loading />}
        {error && <ErrorMessage message={error} />}
        {data && (
          <>
            <Table
              rowKey={(row) => row.id}
              onRowClick={(row) => navigate(`/cases/${row.id}`)}
              columns={[
                { key: 'caseNumber', header: 'Case ID', render: (r) => <span className="font-mono text-xs text-slate-500">SKC-{r.id.slice(0, 6).toUpperCase()}</span> },
                { key: 'user', header: 'User', render: (r) => r.user?.name },
                { key: 'phone', header: 'Phone', render: (r) => r.user?.phone },
                { key: 'doctor', header: 'Doctor', render: (r) => r.doctor?.name || '—' },
                { key: 'status', header: 'Status', render: (r) => <StatusBadge status={r.status} /> },
                { key: 'createdAt', header: 'Created', render: (r) => new Date(r.createdAt).toLocaleDateString() },
                {
                  key: 'actions',
                  header: 'Actions',
                  render: (r) => ['SOLVED', 'CLOSED'].includes(r.status) ? null : (
                    <button
                      type="button"
                      onClick={(e) => { e.stopPropagation(); setAssigningCaseId(r.id); }}
                      className="inline-flex items-center gap-1 rounded-full border border-brand-teal/30 bg-brand-teal/10 px-2.5 py-1 text-[11px] font-semibold text-brand-teal transition hover:bg-brand-teal/20"
                    >
                      <UserPlus className="h-3.5 w-3.5" />
                      {r.doctor ? 'Reassign' : 'Assign'}
                    </button>
                  ),
                },
              ]}
              rows={data.data}
            />
            <div className="mt-4 flex items-center justify-between text-sm text-slate-500">
              <span>Page {data.page} of {data.totalPages || 1} · {data.total} cases</span>
              <div className="flex gap-2">
                <Button variant="secondary" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Previous</Button>
                <Button variant="secondary" disabled={page >= data.totalPages} onClick={() => setPage((p) => p + 1)}>Next</Button>
              </div>
            </div>
          </>
        )}
      </Card>

      <AssignDoctorModal
        caseId={assigningCaseId}
        open={!!assigningCaseId}
        onClose={() => setAssigningCaseId(null)}
        onAssigned={refetch}
      />
    </div>
  );
}
