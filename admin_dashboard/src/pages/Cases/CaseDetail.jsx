import { useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { api, apiErrorMessage } from '../../lib/api';
import { useApiQuery } from '../../hooks/useApiQuery';
import { useSocketEvent } from '../../lib/socket';
import Card from '../../components/Card';
import Button from '../../components/Button';
import StatusBadge from '../../components/StatusBadge';
import Modal from '../../components/Modal';
import { Select } from '../../components/Field';
import { Loading, ErrorMessage } from '../../components/Feedback';

const NEXT_STATUSES = {
  PENDING: [],
  ASSIGNED: ['IN_REVIEW', 'CLOSED'],
  IN_REVIEW: ['CLOSED'],
  SOLVED: ['CLOSED'],
  CLOSED: [],
};

export default function CaseDetail() {
  const { id } = useParams();
  const { data, loading, error, refetch } = useApiQuery(() => api.get(`/admin/cases/${id}`), [id]);
  const { data: doctorsData } = useApiQuery(() => api.get('/admin/doctors', { params: { limit: 100 } }), []);
  const [selectedDoctor, setSelectedDoctor] = useState('');
  const [nextStatus, setNextStatus] = useState('');
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState(null);
  const [lightboxUrl, setLightboxUrl] = useState(null);

  useSocketEvent(['case_assigned', 'new_message', 'solution_added'], refetch);

  if (loading) return <Loading />;
  if (error) return <ErrorMessage message={error} />;

  const caseRecord = data.case;

  async function handleAssign() {
    if (!selectedDoctor) return;
    setBusy(true);
    setActionError(null);
    try {
      await api.patch(`/admin/cases/${id}/assign`, { doctorId: selectedDoctor });
      await refetch();
      setSelectedDoctor('');
    } catch (err) {
      setActionError(apiErrorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  async function handleStatusChange() {
    if (!nextStatus) return;
    setBusy(true);
    setActionError(null);
    try {
      await api.patch(`/admin/cases/${id}/status`, { status: nextStatus });
      await refetch();
      setNextStatus('');
    } catch (err) {
      setActionError(apiErrorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  const availableNext = NEXT_STATUSES[caseRecord.status] || [];

  return (
    <div className="flex flex-col gap-4">
      <Link to="/cases" className="text-sm text-brand-teal hover:underline">← Back to cases</Link>

      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-slate-800">Case #{caseRecord.id.slice(0, 8)}</h1>
        <StatusBadge status={caseRecord.status} />
      </div>

      {actionError && <ErrorMessage message={actionError} />}

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <h3 className="mb-3 text-sm font-semibold text-slate-600">Patient</h3>
          <div className="text-sm text-slate-700">
            <div>{caseRecord.user?.name} · {caseRecord.user?.phone}</div>
            <div className="text-slate-400">{caseRecord.user?.gender || '—'}, {caseRecord.user?.age || '—'}</div>
          </div>

          <h3 className="mb-3 mt-6 text-sm font-semibold text-slate-600">Answers</h3>
          <div className="flex flex-col gap-3">
            {caseRecord.questionFlow?.questions?.map((q) => (
              <div key={q.id} className="text-sm">
                <div className="text-slate-500">{q.text}</div>
                <div className="font-medium text-slate-800">
                  {Array.isArray(caseRecord.answers?.[q.id]) ? caseRecord.answers[q.id].join(', ') : String(caseRecord.answers?.[q.id] ?? '—')}
                </div>
              </div>
            ))}
          </div>

          {caseRecord.photos?.length > 0 && (
            <>
              <h3 className="mb-3 mt-6 text-sm font-semibold text-slate-600">Photos</h3>
              <div className="flex flex-wrap gap-2">
                {caseRecord.photos.map((url) => (
                  <button key={url} type="button" onClick={() => setLightboxUrl(url)} title="Click to enlarge">
                    <img src={url} alt="Case attachment" className="h-24 w-24 rounded-btn object-cover transition hover:opacity-80" />
                  </button>
                ))}
              </div>
            </>
          )}

          <h3 className="mb-3 mt-6 text-sm font-semibold text-slate-600">Videos</h3>
          {caseRecord.videos?.length > 0 ? (
            <div className="flex flex-wrap gap-3">
              {caseRecord.videos.map((url) => (
                <video key={url} src={url} controls preload="metadata" className="max-w-full rounded-btn bg-slate-900 sm:w-72">
                  Your browser cannot play this video. <a href={url}>Download it instead.</a>
                </video>
              ))}
            </div>
          ) : (
            <p className="text-sm text-slate-400">The patient did not upload a video for this case.</p>
          )}

          {caseRecord.solution && (
            <>
              <h3 className="mb-3 mt-6 text-sm font-semibold text-slate-600">Solution</h3>
              <p className="text-sm text-slate-700">{caseRecord.solution.text}</p>
            </>
          )}
        </Card>

        <div className="flex flex-col gap-4">
          <Card>
            <h3 className="mb-3 text-sm font-semibold text-slate-600">Assign doctor</h3>
            {['SOLVED', 'CLOSED'].includes(caseRecord.status) ? (
              <p className="text-sm text-slate-400">
                This case is {caseRecord.status.toLowerCase()}{caseRecord.doctor ? ` (by ${caseRecord.doctor.name})` : ''} and can no longer be reassigned.
              </p>
            ) : (
              <>
                <Select value={selectedDoctor} onChange={(e) => setSelectedDoctor(e.target.value)}>
                  <option value="">Select a doctor…</option>
                  {doctorsData?.data?.map((d) => (
                    <option key={d.id} value={d.id} disabled={!d.isAvailable}>{d.name}{d.isAvailable ? '' : ' (unavailable)'}</option>
                  ))}
                </Select>
                <Button className="mt-3 w-full" disabled={!selectedDoctor || busy} onClick={handleAssign}>
                  {caseRecord.doctor ? 'Reassign' : 'Assign'}
                </Button>
                {caseRecord.doctor && (
                  <p className="mt-2 text-xs text-slate-400">Currently: {caseRecord.doctor.name}</p>
                )}
              </>
            )}
          </Card>

          <Card>
            <h3 className="mb-3 text-sm font-semibold text-slate-600">Update status</h3>
            {availableNext.length ? (
              <>
                <Select value={nextStatus} onChange={(e) => setNextStatus(e.target.value)}>
                  <option value="">Select next status…</option>
                  {availableNext.map((s) => <option key={s} value={s}>{s}</option>)}
                </Select>
                <Button className="mt-3 w-full" disabled={!nextStatus || busy} onClick={handleStatusChange}>
                  Update
                </Button>
              </>
            ) : (
              <p className="text-sm text-slate-400">No further transitions available.</p>
            )}
          </Card>

          <Card>
            <h3 className="mb-3 text-sm font-semibold text-slate-600">Timeline</h3>
            <ol className="flex flex-col gap-3">
              {caseRecord.statusHistory?.map((h) => (
                <li key={h.id} className="text-sm">
                  <div className="font-medium text-slate-800">{h.status}</div>
                  <div className="text-xs text-slate-400">
                    {new Date(h.createdAt).toLocaleString()} · {h.changedByType}
                    {h.note ? ` · ${h.note}` : ''}
                  </div>
                </li>
              ))}
            </ol>
          </Card>
        </div>
      </div>

      <Modal open={!!lightboxUrl} onClose={() => setLightboxUrl(null)} title="Case photo">
        <img src={lightboxUrl} alt="Case attachment" className="max-h-[70vh] w-full rounded-btn object-contain" />
      </Modal>
    </div>
  );
}
