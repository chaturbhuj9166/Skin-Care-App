import { useState } from 'react';
import { api, apiErrorMessage } from '../lib/api';
import { useApiQuery } from '../hooks/useApiQuery';
import { useSocketEvent } from '../lib/socket';
import Card from '../components/Card';
import Button from '../components/Button';
import Modal from '../components/Modal';
import ConfirmDialog from '../components/ConfirmDialog';
import Field, { TextInput } from '../components/Field';
import { Loading, ErrorMessage } from '../components/Feedback';

function emptyForm() {
  return { name: '', email: '', phone: '', specialization: '', experience: '', password: '' };
}

export default function Doctors() {
  const { data, loading, error, refetch } = useApiQuery(() => api.get('/admin/doctors', { params: { limit: 100 } }), []);
  useSocketEvent('doctor_availability_changed', refetch);
  const [editing, setEditing] = useState(null); // doctor object, or {} for new
  const [form, setForm] = useState(emptyForm());
  const [formError, setFormError] = useState(null);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(null);

  function openCreate() {
    setForm(emptyForm());
    setFormError(null);
    setEditing({});
  }
  function openEdit(doctor) {
    setForm({ name: doctor.name, email: doctor.email, phone: doctor.phone, specialization: doctor.specialization || '', experience: doctor.experience || '', password: '' });
    setFormError(null);
    setEditing(doctor);
  }

  async function handleSave() {
    setSaving(true);
    setFormError(null);
    try {
      const payload = {
        name: form.name,
        email: form.email,
        phone: form.phone,
        specialization: form.specialization || undefined,
        experience: form.experience ? Number(form.experience) : undefined,
        // Blank on edit = keep the current password.
        password: form.password || undefined,
      };
      if (editing.id) {
        await api.put(`/admin/doctors/${editing.id}`, payload);
      } else {
        await api.post('/admin/doctors', payload);
      }
      setEditing(null);
      refetch();
    } catch (err) {
      setFormError(apiErrorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  async function toggleAvailability(doctor) {
    await api.put(`/admin/doctors/${doctor.id}`, { isAvailable: !doctor.isAvailable });
    refetch();
  }

  async function handleDelete() {
    await api.delete(`/admin/doctors/${deleting.id}`);
    setDeleting(null);
    refetch();
  }

  if (loading) return <Loading />;
  if (error) return <ErrorMessage message={error} />;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-slate-800">Doctors</h1>
        <Button onClick={openCreate}>+ Add doctor</Button>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {data.data.map((doctor) => (
          <Card key={doctor.id}>
            <div className="flex items-start justify-between">
              <div className="flex items-center gap-3">
                {doctor.avatar ? (
                  <img src={doctor.avatar} alt={doctor.name} className="h-11 w-11 rounded-full object-cover" />
                ) : (
                  <div className="flex h-11 w-11 items-center justify-center rounded-full bg-brand-teal/10 text-sm font-semibold text-brand-teal">
                    {doctor.name?.slice(0, 2).toUpperCase()}
                  </div>
                )}
                <div>
                  <div className="font-semibold text-slate-800">{doctor.name}</div>
                  <div className="text-xs text-slate-400">{doctor.specialization || 'General'}</div>
                </div>
              </div>
              <span className={`h-2.5 w-2.5 rounded-full ${doctor.isAvailable ? 'bg-brand-green' : 'bg-slate-300'}`} title={doctor.isAvailable ? 'Available' : 'Unavailable'} />
            </div>
            <div className="mt-3 text-sm text-slate-500">{doctor.email}</div>
            <div className="text-sm text-slate-500">{doctor.phone}</div>
            <div className="mt-3 flex gap-4 text-sm">
              <div><span className="font-semibold text-slate-800">{doctor.totalCases ?? 0}</span> <span className="text-slate-400">cases</span></div>
              <div><span className="font-semibold text-slate-800">{doctor.solvedCases ?? 0}</span> <span className="text-slate-400">solved</span></div>
              <div>
                <span className="font-semibold text-slate-800">{doctor.avgRating ? doctor.avgRating.toFixed(1) : '—'}</span>{' '}
                <span className="text-slate-400">rating{doctor.reviewCount ? ` (${doctor.reviewCount})` : ''}</span>
              </div>
            </div>
            <div className="mt-4 flex gap-2">
              <Button variant="secondary" onClick={() => openEdit(doctor)}>Edit</Button>
              <Button variant="secondary" onClick={() => toggleAvailability(doctor)}>{doctor.isAvailable ? 'Mark unavailable' : 'Mark available'}</Button>
              <Button variant="danger" onClick={() => setDeleting(doctor)}>Delete</Button>
            </div>
          </Card>
        ))}
      </div>

      <Modal open={!!editing} onClose={() => setEditing(null)} title={editing?.id ? 'Edit doctor' : 'Add doctor'} footer={
        <>
          <Button variant="secondary" onClick={() => setEditing(null)}>Cancel</Button>
          <Button onClick={handleSave} disabled={saving}>{saving ? 'Saving…' : 'Save'}</Button>
        </>
      }>
        <Field label="Name"><TextInput value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></Field>
        <Field label="Email"><TextInput type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></Field>
        <Field label="Phone">
          <TextInput value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} placeholder="+919810000000" />
        </Field>
        <Field label="Specialization"><TextInput value={form.specialization} onChange={(e) => setForm({ ...form, specialization: e.target.value })} /></Field>
        <Field label="Experience (years)"><TextInput type="number" value={form.experience} onChange={(e) => setForm({ ...form, experience: e.target.value })} /></Field>
        <Field label={editing?.id ? 'New password (leave blank to keep current)' : 'Login password (doctor signs in with email + this password)'}>
          <TextInput type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} placeholder="Min. 6 characters" autoComplete="new-password" />
        </Field>
        {formError && <ErrorMessage message={formError} />}
      </Modal>

      <ConfirmDialog
        open={!!deleting}
        onClose={() => setDeleting(null)}
        onConfirm={handleDelete}
        title="Delete doctor"
        description={`Delete ${deleting?.name}? This cannot be undone.`}
        confirmLabel="Delete"
      />
    </div>
  );
}
