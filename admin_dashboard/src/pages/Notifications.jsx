import { useMemo, useState } from 'react';
import { api, apiErrorMessage } from '../lib/api';
import { useApiQuery } from '../hooks/useApiQuery';
import { useDebouncedValue } from '../hooks/useDebouncedValue';
import { toastSuccess, toastError } from '../store/toastStore';
import Card from '../components/Card';
import Table from '../components/Table';
import Button from '../components/Button';
import Field, { TextInput, TextArea, Select } from '../components/Field';
import { Loading, ErrorMessage } from '../components/Feedback';

const TARGETS = [
  { value: 'ALL_USERS', label: 'All users' },
  { value: 'ALL_DOCTORS', label: 'All doctors' },
  { value: 'SPECIFIC_USER', label: 'Specific user' },
  { value: 'SPECIFIC_DOCTOR', label: 'Specific doctor' },
];

// One broadcast fans out into one Notification row per recipient, all sharing
// the same title/body/timestamp — so the history is grouped back together and
// the recipient count tells a blast apart from a single-recipient send.
function groupNotifications(rows) {
  const groups = new Map();
  for (const n of rows) {
    const key = `${n.title}|${n.body}|${n.createdAt}`;
    if (!groups.has(key)) {
      groups.set(key, { key, title: n.title, body: n.body, createdAt: n.createdAt, userType: n.userType, sentByName: n.sentByName, count: 0 });
    }
    groups.get(key).count += 1;
  }
  return Array.from(groups.values());
}

function targetLabel(group) {
  if (group.userType === 'DOCTOR') return group.count > 1 ? 'All doctors' : 'Specific doctor';
  return group.count > 1 ? 'All users' : 'Specific user';
}

export default function Notifications() {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [target, setTarget] = useState('ALL_USERS');
  const [targetId, setTargetId] = useState('');
  const [targetQuery, setTargetQuery] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState(null);

  const { data, loading, error: listError, refetch } = useApiQuery(() => api.get('/admin/notifications', { params: { limit: 50 } }), []);

  const isSpecific = target === 'SPECIFIC_USER' || target === 'SPECIFIC_DOCTOR';
  const searchEndpoint = target === 'SPECIFIC_USER' ? '/admin/users' : '/admin/doctors';
  const debouncedTargetQuery = useDebouncedValue(targetQuery);
  const { data: candidates } = useApiQuery(
    () => (isSpecific ? api.get(searchEndpoint, { params: { search: debouncedTargetQuery, limit: 10 } }) : Promise.resolve({ data: null })),
    [isSpecific, searchEndpoint, debouncedTargetQuery],
  );

  const grouped = useMemo(() => groupNotifications(data?.data || []), [data]);

  function handleTargetTypeChange(value) {
    setTarget(value);
    setTargetId('');
    setTargetQuery('');
  }

  async function handleSend(e) {
    e.preventDefault();
    if (isSpecific && !targetId) {
      setError('Please select a recipient from the list.');
      return;
    }
    setSending(true);
    setError(null);
    try {
      await api.post('/admin/notifications/send', { title, body, target, ...(targetId && { targetId }) });
      setTitle('');
      setBody('');
      setTargetId('');
      setTargetQuery('');
      toastSuccess('Notification sent.');
      refetch();
    } catch (err) {
      const message = apiErrorMessage(err);
      setError(message);
      toastError(message);
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold text-slate-800">Notifications</h1>

      <Card>
        <h3 className="mb-3 text-sm font-semibold text-slate-600">Send broadcast</h3>
        <form onSubmit={handleSend} className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <Field label="Title"><TextInput required value={title} onChange={(e) => setTitle(e.target.value)} /></Field>
          <Field label="Target">
            <Select value={target} onChange={(e) => handleTargetTypeChange(e.target.value)}>
              {TARGETS.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
            </Select>
          </Field>
          <div className="sm:col-span-2">
            <Field label="Message"><TextArea rows={3} required value={body} onChange={(e) => setBody(e.target.value)} /></Field>
          </div>
          {isSpecific && (
            <div className="sm:col-span-2">
              <Field label={target === 'SPECIFIC_USER' ? 'Find user by name or phone' : 'Find doctor by name or phone'}>
                <TextInput
                  value={targetQuery}
                  onChange={(e) => { setTargetQuery(e.target.value); setTargetId(''); }}
                  placeholder="Start typing to search…"
                />
              </Field>
              {targetQuery && (
                <div className="mt-2 max-h-48 overflow-y-auto rounded-xl border border-slate-200">
                  {candidates?.data?.length ? candidates.data.map((c) => (
                    <button
                      type="button"
                      key={c.id}
                      onClick={() => { setTargetId(c.id); setTargetQuery(c.name); }}
                      className={`flex w-full items-center justify-between px-3 py-2 text-left text-sm hover:bg-slate-50 ${targetId === c.id ? 'bg-brand-teal/5 text-brand-teal' : 'text-slate-700'}`}
                    >
                      <span>{c.name}</span>
                      <span className="text-xs text-slate-400">{c.phone}</span>
                    </button>
                  )) : (
                    <div className="px-3 py-2 text-sm text-slate-400">No matches.</div>
                  )}
                </div>
              )}
              {targetId && <p className="mt-1 text-xs text-green-600">Recipient selected.</p>}
            </div>
          )}
          {error && <div className="sm:col-span-2"><ErrorMessage message={error} /></div>}
          <div className="sm:col-span-2">
            <Button type="submit" disabled={sending}>{sending ? 'Sending…' : 'Send notification'}</Button>
          </div>
        </form>
      </Card>

      <Card>
        <h3 className="mb-3 text-sm font-semibold text-slate-600">Delivery history</h3>
        {loading && <Loading />}
        {listError && <ErrorMessage message={listError} />}
        {data && (
          <Table
            rowKey={(row) => row.key}
            emptyMessage="No notifications sent yet."
            columns={[
              { key: 'title', header: 'Title', render: (r) => (
                <div>
                  <div className="font-medium text-slate-800">{r.title}</div>
                  <div className="text-xs text-slate-500">{r.body}</div>
                </div>
              ) },
              { key: 'target', header: 'Target', render: (r) => targetLabel(r) },
              { key: 'recipients', header: 'Recipients', render: (r) => r.count },
              { key: 'sentBy', header: 'Sent by', render: (r) => r.sentByName || '—' },
              { key: 'sentAt', header: 'Sent at', render: (r) => new Date(r.createdAt).toLocaleString() },
            ]}
            rows={grouped}
          />
        )}
      </Card>
    </div>
  );
}
