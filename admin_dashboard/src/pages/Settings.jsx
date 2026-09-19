import { useState } from 'react';
import { api, apiErrorMessage } from '../lib/api';
import { useAuthStore } from '../store/authStore';
import { toastSuccess, toastError } from '../store/toastStore';
import Card from '../components/Card';
import Button from '../components/Button';
import Field, { TextInput } from '../components/Field';
import { ErrorMessage } from '../components/Feedback';

export default function Settings() {
  const admin = useAuthStore((s) => s.admin);
  const updateAdmin = useAuthStore((s) => s.updateAdmin);

  const [name, setName] = useState(admin?.name || '');
  const [email, setEmail] = useState(admin?.email || '');
  const [profileSaving, setProfileSaving] = useState(false);
  const [profileError, setProfileError] = useState(null);

  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [passwordSaving, setPasswordSaving] = useState(false);
  const [passwordError, setPasswordError] = useState(null);

  async function handleProfileSave(e) {
    e.preventDefault();
    setProfileSaving(true);
    setProfileError(null);
    try {
      const { data } = await api.put('/admin/profile', { name, email });
      updateAdmin(data.admin);
      toastSuccess('Profile updated.');
    } catch (err) {
      const message = apiErrorMessage(err);
      setProfileError(message);
      toastError(message);
    } finally {
      setProfileSaving(false);
    }
  }

  async function handlePasswordChange(e) {
    e.preventDefault();
    setPasswordSaving(true);
    setPasswordError(null);
    try {
      await api.put('/admin/profile/password', { oldPassword, newPassword });
      setOldPassword('');
      setNewPassword('');
      toastSuccess('Password changed.');
    } catch (err) {
      const message = apiErrorMessage(err);
      setPasswordError(message);
      toastError(message);
    } finally {
      setPasswordSaving(false);
    }
  }

  return (
    <div className="flex max-w-xl flex-col gap-4">
      <h1 className="text-xl font-semibold text-slate-800">Settings</h1>

      <Card>
        <h3 className="mb-3 text-sm font-semibold text-slate-600">Profile</h3>
        <form onSubmit={handleProfileSave}>
          <Field label="Name"><TextInput required value={name} onChange={(e) => setName(e.target.value)} /></Field>
          <Field label="Email"><TextInput type="email" required value={email} onChange={(e) => setEmail(e.target.value)} /></Field>
          {profileError && <div className="mb-3"><ErrorMessage message={profileError} /></div>}
          <Button type="submit" disabled={profileSaving}>{profileSaving ? 'Saving…' : 'Save profile'}</Button>
        </form>
      </Card>

      <Card>
        <h3 className="mb-3 text-sm font-semibold text-slate-600">Change password</h3>
        <form onSubmit={handlePasswordChange}>
          <Field label="Current password"><TextInput type="password" required value={oldPassword} onChange={(e) => setOldPassword(e.target.value)} /></Field>
          <Field label="New password"><TextInput type="password" required minLength={6} value={newPassword} onChange={(e) => setNewPassword(e.target.value)} /></Field>
          {passwordError && <div className="mb-3"><ErrorMessage message={passwordError} /></div>}
          <Button type="submit" disabled={passwordSaving}>{passwordSaving ? 'Saving…' : 'Change password'}</Button>
        </form>
      </Card>
    </div>
  );
}
