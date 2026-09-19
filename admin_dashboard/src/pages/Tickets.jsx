import { useState } from 'react';
import { api, apiErrorMessage } from '../lib/api';
import { useApiQuery } from '../hooks/useApiQuery';
import { useSocketEvent } from '../lib/socket';
import { toastSuccess, toastError } from '../store/toastStore';
import Card from '../components/Card';
import Button from '../components/Button';
import StatusBadge from '../components/StatusBadge';
import { Select, TextArea } from '../components/Field';
import { Loading, ErrorMessage } from '../components/Feedback';

const STATUSES = ['OPEN', 'IN_PROGRESS', 'CLOSED'];
const PRIORITIES = ['LOW', 'MEDIUM', 'HIGH'];

function TicketRow({ ticket, onUpdated }) {
  const [reply, setReply] = useState('');
  const [status, setStatus] = useState(ticket.status);
  const [saving, setSaving] = useState(false);

  async function handleUpdate() {
    setSaving(true);
    try {
      await api.patch(`/admin/tickets/${ticket.id}`, { status, ...(reply.trim() && { reply: reply.trim() }) });
      setReply('');
      toastSuccess('Ticket updated.');
      onUpdated();
    } catch (err) {
      toastError(apiErrorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Card>
      <div className="flex items-start justify-between">
        <div>
          <div className="font-semibold text-slate-800">{ticket.subject}</div>
          <div className="text-xs text-slate-400">{ticket.user?.name} · {new Date(ticket.createdAt).toLocaleString()}</div>
        </div>
        <div className="flex gap-2">
          <StatusBadge status={ticket.priority} />
          <StatusBadge status={ticket.status} />
        </div>
      </div>
      <p className="mt-3 text-sm text-slate-600">{ticket.description}</p>
      {ticket.reply && (
        <div className="mt-3 rounded-btn bg-teal-50 px-3 py-2 text-sm text-slate-700">
          <span className="font-medium">Support reply:</span> {ticket.reply}
        </div>
      )}
      <div className="mt-4 flex flex-col gap-2 sm:flex-row">
        <Select value={status} onChange={(e) => setStatus(e.target.value)} className="sm:w-40">
          {STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
        </Select>
        <TextArea rows={2} placeholder="Reply to this ticket…" value={reply} onChange={(e) => setReply(e.target.value)} className="flex-1" />
        <Button disabled={saving} onClick={handleUpdate}>{saving ? 'Saving…' : 'Update'}</Button>
      </div>
    </Card>
  );
}

export default function Tickets() {
  const [status, setStatus] = useState('');
  const [priority, setPriority] = useState('');
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

      {loading && <Loading />}
      {error && <ErrorMessage message={error} />}
      <div className="flex flex-col gap-3">
        {data?.data?.map((ticket) => <TicketRow key={ticket.id} ticket={ticket} onUpdated={refetch} />)}
        {data && !data.data.length && <div className="py-12 text-center text-sm text-slate-400">No tickets found.</div>}
      </div>
    </div>
  );
}
