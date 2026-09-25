import { useState } from 'react';
import { GripVertical, Plus, X } from 'lucide-react';
import { api, apiErrorMessage } from '../lib/api';
import { useApiQuery } from '../hooks/useApiQuery';
import { toastSuccess, toastError } from '../store/toastStore';
import Card from '../components/Card';
import Button from '../components/Button';
import ConfirmDialog from '../components/ConfirmDialog';
import Field, { TextInput, Select } from '../components/Field';
import { Loading, ErrorMessage } from '../components/Feedback';

const TYPES = [
  { value: 'text', label: 'Text' },
  { value: 'single_choice', label: 'Single choice' },
  { value: 'multiple_choice', label: 'Multiple choice' },
  { value: 'yes_no', label: 'Yes / No' },
  { value: 'rating', label: 'Rating (1-5)' },
  { value: 'photo_upload', label: 'Photo upload' },
];

function emptyQuestion() {
  return { id: `new-${crypto.randomUUID()}`, text: '', type: 'text', required: true, options: [] };
}

function OptionsEditor({ options, onChange }) {
  const list = options || [];

  function updateOption(i, value) {
    onChange(list.map((o, idx) => (idx === i ? value : o)));
  }
  function removeOption(i) {
    onChange(list.filter((_, idx) => idx !== i));
  }
  function addOption() {
    onChange([...list, '']);
  }

  return (
    <Field label="Answer options (at least 2)">
      <div className="flex flex-col gap-2">
        {list.map((opt, i) => (
          <div key={i} className="flex items-center gap-2">
            <TextInput
              value={opt}
              placeholder={`Option ${i + 1}`}
              onChange={(e) => updateOption(i, e.target.value)}
            />
            <button
              type="button"
              onClick={() => removeOption(i)}
              className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-lg text-slate-400 hover:bg-red-50 hover:text-red-500"
              title="Remove option"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        ))}
        <button
          type="button"
          onClick={addOption}
          className="inline-flex w-fit items-center gap-1 rounded-lg border border-dashed border-slate-300 px-3 py-1.5 text-xs font-medium text-slate-500 hover:border-brand-teal hover:text-brand-teal"
        >
          <Plus className="h-3.5 w-3.5" />
          Add answer option
        </button>
      </div>
    </Field>
  );
}

function QuestionEditor({ question, index, total, onChange, onRemove, onMove, dragHandlers, dragging }) {
  const needsOptions = question.type === 'single_choice' || question.type === 'multiple_choice';

  return (
    <div
      className={`rounded-btn border border-slate-200 p-4 transition ${dragging ? 'opacity-40' : ''}`}
      onDragOver={dragHandlers.onDragOver}
      onDrop={dragHandlers.onDrop}
    >
      <div className="mb-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span
            draggable
            onDragStart={dragHandlers.onDragStart}
            onDragEnd={dragHandlers.onDragEnd}
            title="Drag to reorder"
            className="cursor-grab text-slate-300 hover:text-slate-500 active:cursor-grabbing"
          >
            <GripVertical className="h-4 w-4" />
          </span>
          <span className="text-xs font-medium text-slate-400">Question {index + 1}</span>
        </div>
        <div className="flex gap-2">
          <button type="button" disabled={index === 0} onClick={() => onMove(index, -1)} className="text-xs text-slate-500 disabled:opacity-30">↑</button>
          <button type="button" disabled={index === total - 1} onClick={() => onMove(index, 1)} className="text-xs text-slate-500 disabled:opacity-30">↓</button>
          <button type="button" onClick={onRemove} className="text-xs text-red-500">Remove</button>
        </div>
      </div>

      <Field label="Question text">
        <TextInput value={question.text} onChange={(e) => onChange({ ...question, text: e.target.value })} />
      </Field>

      <div className="grid grid-cols-2 gap-3">
        <Field label="Type">
          <Select value={question.type} onChange={(e) => onChange({ ...question, type: e.target.value, options: [] })}>
            {TYPES.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
          </Select>
        </Field>
        <Field label="Required">
          <Select value={question.required ? 'yes' : 'no'} onChange={(e) => onChange({ ...question, required: e.target.value === 'yes' })}>
            <option value="yes">Required</option>
            <option value="no">Optional</option>
          </Select>
        </Field>
      </div>

      {needsOptions && (
        <OptionsEditor
          options={question.options}
          onChange={(options) => onChange({ ...question, options })}
        />
      )}
    </div>
  );
}

function FlowPreview({ title, questions }) {
  return (
    <Card>
      <h3 className="mb-3 text-sm font-semibold text-slate-600">Preview</h3>
      {/* Patients answer this on a phone, so the preview is framed like one. */}
      <div className="mx-auto w-[320px] rounded-[2.25rem] border-[10px] border-slate-800 bg-white shadow-xl">
        <div className="flex justify-center pt-2">
          <span className="h-1.5 w-16 rounded-full bg-slate-800" />
        </div>
        <div className="max-h-[520px] overflow-y-auto px-4 pb-6 pt-4">
          <h4 className="mb-4 text-lg font-heading font-semibold text-slate-800">{title || 'Untitled flow'}</h4>
          <div className="flex flex-col gap-4">
            {questions.map((q) => (
              <div key={q.id}>
                <div className="text-sm font-medium text-slate-700">{q.text || 'Untitled question'} {q.required && <span className="text-red-500">*</span>}</div>
                {q.type === 'text' && <div className="mt-1 h-9 rounded-btn border border-dashed border-slate-200" />}
                {(q.type === 'single_choice' || q.type === 'multiple_choice') && (
                  <div className="mt-1 flex flex-wrap gap-2">
                    {(q.options || []).map((opt) => (
                      <span key={opt} className="rounded-full border border-slate-200 px-3 py-1 text-xs text-slate-600">{opt}</span>
                    ))}
                  </div>
                )}
                {q.type === 'yes_no' && <div className="mt-1 flex gap-2 text-xs text-slate-500"><span className="rounded-full border px-3 py-1">Yes</span><span className="rounded-full border px-3 py-1">No</span></div>}
                {q.type === 'rating' && <div className="mt-1 text-slate-400">★ ★ ★ ★ ★</div>}
                {q.type === 'photo_upload' && <div className="mt-1 h-16 w-16 rounded-btn border border-dashed border-slate-200" />}
              </div>
            ))}
          </div>
        </div>
      </div>
    </Card>
  );
}

function FlowEditor({ flow, onSaved, onClose }) {
  const [title, setTitle] = useState(flow.title);
  const [questions, setQuestions] = useState(flow.questions);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [dragIndex, setDragIndex] = useState(null);

  function updateQuestion(index, next) {
    setQuestions((qs) => qs.map((q, i) => (i === index ? next : q)));
  }
  function removeQuestion(index) {
    setQuestions((qs) => qs.filter((_, i) => i !== index));
  }
  function addQuestion() {
    setQuestions((qs) => [...qs, emptyQuestion()]);
  }
  function moveQuestion(index, dir) {
    setQuestions((qs) => {
      const next = [...qs];
      const target = index + dir;
      if (target < 0 || target >= next.length) return qs;
      [next[index], next[target]] = [next[target], next[index]];
      return next;
    });
  }
  function reorderQuestion(from, to) {
    if (from === to) return;
    setQuestions((qs) => {
      const next = [...qs];
      const [moved] = next.splice(from, 1);
      next.splice(to, 0, moved);
      return next;
    });
  }

  async function save(activate) {
    setSaving(true);
    setError(null);
    const payload = {
      title,
      questions: questions.map((q) => {
        const cleanOptions = (q.options || []).map((o) => o.trim()).filter(Boolean);
        return {
          ...(String(q.id).startsWith('new-') ? {} : { id: q.id }),
          text: q.text,
          type: q.type,
          required: q.required,
          ...(cleanOptions.length ? { options: cleanOptions } : {}),
        };
      }),
      ...(activate !== undefined ? { isActive: activate } : {}),
    };
    try {
      if (flow.id) {
        await api.put(`/admin/question-flows/${flow.id}`, payload);
      } else {
        await api.post('/admin/question-flows', { title: payload.title, questions: payload.questions });
      }
      toastSuccess(activate ? 'Flow saved and activated.' : 'Flow saved as draft.');
      onSaved();
    } catch (err) {
      const message = apiErrorMessage(err);
      setError(message);
      toastError(message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
      <Card>
        <div className="mb-1 flex items-center justify-between gap-3">
          <h3 className="text-sm font-semibold text-slate-600">{flow.id ? 'Edit flow' : 'New flow'}</h3>
          <button type="button" onClick={onClose} className="text-xs font-medium text-slate-400 hover:text-slate-600">Close</button>
        </div>
        <Field label="Flow title">
          <TextInput value={title} onChange={(e) => setTitle(e.target.value)} />
        </Field>

        <div className="flex flex-col gap-3">
          {questions.map((q, index) => (
            <QuestionEditor
              key={q.id}
              question={q}
              index={index}
              total={questions.length}
              onChange={(next) => updateQuestion(index, next)}
              onRemove={() => removeQuestion(index)}
              onMove={moveQuestion}
              dragging={dragIndex === index}
              dragHandlers={{
                onDragStart: (e) => { setDragIndex(index); e.dataTransfer.effectAllowed = 'move'; },
                onDragEnd: () => setDragIndex(null),
                onDragOver: (e) => e.preventDefault(),
                onDrop: (e) => {
                  e.preventDefault();
                  if (dragIndex !== null) reorderQuestion(dragIndex, index);
                  setDragIndex(null);
                },
              }}
            />
          ))}
        </div>

        <Button variant="secondary" className="mt-3" onClick={addQuestion}>+ Add question</Button>

        {error && <div className="mt-3"><ErrorMessage message={error} /></div>}

        <div className="mt-4 flex gap-2">
          <Button variant="secondary" disabled={saving} onClick={() => save(undefined)}>Save draft</Button>
          <Button disabled={saving} onClick={() => save(true)}>Save & activate</Button>
        </div>
      </Card>

      <FlowPreview title={title} questions={questions} />
    </div>
  );
}

export default function QuestionBuilder() {
  const { data, loading, error, refetch } = useApiQuery(() => api.get('/admin/question-flows'), []);
  const [selectedId, setSelectedId] = useState(null);
  const [deleting, setDeleting] = useState(null);
  const [deleteBusy, setDeleteBusy] = useState(false);
  const [togglingId, setTogglingId] = useState(null);

  if (loading) return <Loading />;
  if (error) return <ErrorMessage message={error} />;

  const flows = data.data;
  const selected = selectedId === 'new' ? { title: '', questions: [emptyQuestion()] } : flows.find((f) => f.id === selectedId);

  // Activating a flow deactivates every other one server-side, so the whole
  // list has to be refetched rather than patched in place.
  async function toggleActive(flow) {
    setTogglingId(flow.id);
    try {
      await api.put(`/admin/question-flows/${flow.id}`, { isActive: !flow.isActive });
      await refetch();
      toastSuccess(flow.isActive ? `"${flow.title}" moved to draft.` : `"${flow.title}" is now the active flow.`);
    } catch (err) {
      toastError(apiErrorMessage(err));
    } finally {
      setTogglingId(null);
    }
  }

  async function handleDelete() {
    setDeleteBusy(true);
    try {
      await api.delete(`/admin/question-flows/${deleting.id}`);
      toastSuccess('Flow deleted.');
      setDeleting(null);
      if (selectedId === deleting.id) setSelectedId(null);
      refetch();
    } catch (err) {
      toastError(apiErrorMessage(err));
    } finally {
      setDeleteBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-slate-800">Question Builder</h1>
        <Button onClick={() => setSelectedId('new')}>+ New flow</Button>
      </div>

      <Card>
        <ul className="divide-y divide-slate-100">
          {flows.map((flow) => (
            <li key={flow.id} className="flex items-center justify-between py-3">
              <button className="text-left text-sm font-medium text-slate-700 hover:text-brand-teal" onClick={() => setSelectedId(flow.id)}>
                {flow.title}
              </button>
              <div className="flex items-center gap-3">
                <button
                  type="button"
                  disabled={togglingId === flow.id}
                  onClick={() => toggleActive(flow)}
                  title={flow.isActive ? 'Move to draft' : 'Make this the active flow'}
                  className={`rounded-full px-2.5 py-0.5 text-xs font-medium transition disabled:opacity-50 ${flow.isActive ? 'bg-green-100 text-green-700 hover:bg-green-200' : 'bg-slate-100 text-slate-500 hover:bg-slate-200'}`}
                >
                  {flow.isActive ? 'Active' : 'Draft'}
                </button>
                <button
                  type="button"
                  onClick={() => setDeleting(flow)}
                  className="text-xs font-medium text-red-500 hover:text-red-600"
                >
                  Delete
                </button>
              </div>
            </li>
          ))}
          {!flows.length && <li className="py-6 text-center text-sm text-slate-400">No question flows yet.</li>}
        </ul>
      </Card>

      {selected && (
        <FlowEditor
          key={selectedId}
          flow={selected}
          onClose={() => setSelectedId(null)}
          onSaved={() => {
            refetch();
            setSelectedId(null);
          }}
        />
      )}

      <ConfirmDialog
        open={!!deleting}
        onClose={() => setDeleting(null)}
        onConfirm={handleDelete}
        title="Delete question flow"
        description={`Delete "${deleting?.title}"? This cannot be undone.`}
        confirmLabel="Delete"
        loading={deleteBusy}
      />
    </div>
  );
}
