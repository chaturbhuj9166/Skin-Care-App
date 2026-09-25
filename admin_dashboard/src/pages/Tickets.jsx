import { useState } from 'react';
import { api, apiErrorMessage } from '../lib/api';
import { useApiQuery } from '../hooks/useApiQuery';
import { useSocketEvent } from '../lib/socket';
import { toastSuccess, toastError } from '../store/toastStore';
import Card from '../components/Card';
import Table from '../components/Table';
import Modal from '../components/Modal';
import Button from '../components/Button';
import StatusBadge from '../components/StatusBadge';
import { Select, TextArea } from '../components/Field';
import { Loading, ErrorMessage } from '../components/Feedback';

const STATUSES = ['OPEN', 'IN_PROGRESS', 'CLOSED'];
const PRIORITIES = ['LOW', 'MEDIUM', 'HIGH'];

// Mirrors the backend rule: a ticket only ever moves forward, never back.
const NEXT_STATUSES = {
  OPEN: ['IN_PROGRESS', 'CLOSED'],
  IN_PROGRESS: ['CLOSED'],
  CLOSED: [],
};

function TicketDetail({ ticket, onClose, onUpdated }) {
  const [reply, setReply] = useState('');
  const [status, setStatus] = useState(ticket.status);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  const nextStatuses = NEXT_STATUSES[ticket.status] || [];

  async function handleUpdate() {
    setSaving(true);
    setError(null);
    try {
      await api.patch(`/admin/tickets/${ticket.id}`, {
        ...(status !== ticket.status && { status }),
        ...(reply.trim() && { reply: reply.trim() }),
      });
      toastSuccess('Ticket updated.');
      onUpdated();
      onClose();
    } catch (err) {
      const message = apiErrorMessage(err);
      setError(message);
      toastError(message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal
      open
      onClose={onClose}
      title={ticket.subject}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>Cancel</Button>
          <Button disabled={saving} onClick={handleUpdate}>{saving ? 'Saving…' : 'Update ticket'}</Button>
        </>
      }
    >
      <div className="flex items-center gap-2">
        <StatusBadge status={ticket.priority} />
        <StatusBadge status={ticket.status} />
        <span className="text-xs text-slate-400">{ticket.user?.name} · {new Date(ticket.createdAt).toLocaleString()}</span>
      </div>
      <p className="mt-3 text-sm text-slate-600">{ticket.description}</p>
      {ticket.reply && (
        <div className="mt-3 rounded-btn bg-teal-50 px-3 py-2 text-sm text-slate-700">
          <span className="font-medium">Support reply:</span> {ticket.reply}
        </div>
      )}

      <div className="mt-4 flex flex-col gap-2">
        <Select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value={ticket.status}>{ticket.status.replaceAll('_', ' ')} (current)</option>
          {nextStatuses.map((s) => <option key={s} value={s}>{s.replaceAll('_', ' ')}</option>)}
        </Select>
        <TextArea rows={3} placeholder="Reply to this ticket…" value={reply} onChange={(e) => setReply(e.target.value)} />
        {error && <ErrorMessage message={error} />}
      </div>
    </Modal>
  );
}

export default function Tickets() {
  const [status, setStatus] = useState('');
  const [priority, setPriority] = useState('');
  const [selected, setSelected] = useState(null);
  const { data, loading, error, refetch } = useApiQuery(
    () => api.get('/admin/tickets', { params: { ...(status && { status }), ...(priority && { priority }) } }),
    [status, priority],
  );

  useSocketEvent('notification', refetch);

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold text-slate-800">Tickets</h1>

      <div className="flex gap-3">
        <Select value={status} onChange={(e) => setStatus(e.target.value)} className="w-48">
          <option value="">All statuses</option>
          {STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
        </Select>
        <Select value={priority} onChange={(e) => setPriority(e.target.value)} className="w-48">
          <option value="">All priorities</option>
          {PRIORITIES.map((p) => <option key={p} value={p}>{p}</option>)}
        </Select>
      </div>

      <Card>
        {loading && <Loading />}
        {error && <ErrorMessage message={error} />}
        {data && (
          <Table
            rowKey={(row) => row.id}
            onRowClick={(row) => setSelected(row)}
            emptyMessage="No tickets found."
            columns={[
              { key: 'id', header: 'Ticket ID', render: (r) => <span className="font-mono text-xs text-slate-500">TKT-{r.id.slice(0, 6).toUpperCase()}</span> },
              { key: 'user', header: 'User', render: (r) => r.user?.name || '—' },
              { key: 'subject', header: 'Subject' },
              { key: 'priority', header: 'Priority', render: (r) => <StatusBadge status={r.priority} /> },
              { key: 'status', header: 'Status', render: (r) => <StatusBadge status={r.status} /> },
              { key: 'createdAt', header: 'Date', render: (r) => new Date(r.createdAt).toLocaleDateString() },
            ]}
            rows={data.data}
          />
        )}
      </Card>

      {selected && (
        <TicketDetail
          key={selected.id}
          ticket={selected}
          onClose={() => setSelected(null)}
          onUpdated={refetch}
        />
      )}
    </div>
  );
}
