import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../lib/api';
import { useApiQuery } from '../hooks/useApiQuery';
import { useSocketEvent } from '../lib/socket';
import Card from '../components/Card';
import StatusBadge from '../components/StatusBadge';
import { Select } from '../components/Field';
import { Loading, ErrorMessage } from '../components/Feedback';

const STATUSES = ['SCHEDULED', 'ONGOING', 'COMPLETED', 'CANCELLED'];

export default function VideoCalls() {
  const navigate = useNavigate();
  const [status, setStatus] = useState('');

  const { data, loading, error, refetch } = useApiQuery(
    () => api.get('/admin/video-calls', { params: { ...(status && { status }) } }),
    [status],
  );

  useSocketEvent(['call_scheduled', 'case_assigned'], refetch);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-slate-800">Video calls</h1>
        <Select value={status} onChange={(e) => setStatus(e.target.value)} className="w-48">
          <option value="">All statuses</option>
          {STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
        </Select>
      </div>
      <p className="-mt-2 text-sm text-slate-500">
        Calls are scheduled by doctors from within a case. This is a read-only view for oversight.
      </p>

      {loading && <Loading />}
      {error && <ErrorMessage message={error} />}

      {data && (
        <Card>
          <ul className="divide-y divide-slate-100">
            {data.data.map((call) => (
              <li
                key={call.id}
                onClick={() => navigate(`/cases/${call.caseId}`)}
                className="flex cursor-pointer items-center justify-between gap-3 py-3 hover:bg-slate-50"
              >
                <div>
                  <div className="text-sm font-medium text-slate-800">
                    {call.case?.user?.name || 'Unknown patient'} <span className="text-slate-400">with</span> {call.case?.doctor?.name || 'Unassigned doctor'}
                  </div>
                  <div className="text-xs text-slate-400">
                    {new Date(call.scheduledAt).toLocaleString()}
                  </div>
                </div>
                <StatusBadge status={call.status} />
              </li>
            ))}
            {!data.data.length && <li className="py-12 text-center text-sm text-slate-400">No video calls found.</li>}
          </ul>
        </Card>
      )}
    </div>
  );
}
