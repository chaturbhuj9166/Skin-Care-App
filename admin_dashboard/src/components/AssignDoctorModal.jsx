import { useState } from 'react';
import { api, apiErrorMessage } from '../lib/api';
import { useApiQuery } from '../hooks/useApiQuery';
import Modal from './Modal';
import Button from './Button';
import { Select } from './Field';
import { ErrorMessage } from './Feedback';

/// Shared "Assign Doctor" modal, used from the Dashboard's Recent Cases quick-assign
/// action and the Cases table's per-row action.
export default function AssignDoctorModal({ caseId, open, onClose, onAssigned }) {
  const { data: doctorsData } = useApiQuery(
    () => (open ? api.get('/admin/doctors', { params: { limit: 100 } }) : Promise.resolve({ data: null })),
    [open],
  );
  const [selectedDoctor, setSelectedDoctor] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  async function handleAssign() {
    if (!selectedDoctor || !caseId) return;
    setBusy(true);
    setError(null);
    try {
      await api.patch(`/admin/cases/${caseId}/assign`, { doctorId: selectedDoctor });
      setSelectedDoctor('');
      onAssigned?.();
      onClose();
    } catch (err) {
      setError(apiErrorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Assign Doctor"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>Cancel</Button>
          <Button onClick={handleAssign} disabled={!selectedDoctor || busy}>{busy ? 'Assigning…' : 'Assign'}</Button>
        </>
      }
    >
      <Select value={selectedDoctor} onChange={(e) => setSelectedDoctor(e.target.value)}>
        <option value="">Select a doctor…</option>
        {doctorsData?.data?.map((d) => (
          <option key={d.id} value={d.id} disabled={!d.isAvailable}>{d.name}{d.isAvailable ? '' : ' (unavailable)'}</option>
        ))}
      </Select>
      {error && <div className="mt-3"><ErrorMessage message={error} /></div>}
    </Modal>
  );
}
