const STYLES = {
  PENDING: 'border-slate-200 bg-slate-100 text-slate-700',
  ASSIGNED: 'border-blue-200 bg-blue-50 text-blue-700',
  IN_REVIEW: 'border-indigo-200 bg-indigo-50 text-indigo-700',
  SOLVED: 'border-green-200 bg-green-50 text-green-700',
  CLOSED: 'border-slate-300 bg-slate-200 text-slate-800',
  OPEN: 'border-amber-200 bg-amber-50 text-amber-700',
  IN_PROGRESS: 'border-blue-200 bg-blue-50 text-blue-700',
  LOW: 'border-slate-200 bg-slate-100 text-slate-700',
  MEDIUM: 'border-amber-200 bg-amber-50 text-amber-700',
  HIGH: 'border-red-200 bg-red-50 text-red-700',
  SCHEDULED: 'border-blue-200 bg-blue-50 text-blue-700',
  ONGOING: 'border-green-200 bg-green-50 text-green-700',
  COMPLETED: 'border-slate-300 bg-slate-200 text-slate-800',
  CANCELLED: 'border-red-200 bg-red-50 text-red-700',
};

export default function StatusBadge({ status }) {
  const style = STYLES[status] || 'border-slate-200 bg-slate-100 text-slate-700';
  return (
    <span className={`inline-flex rounded-full border px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wide ${style}`}>
      {status?.replaceAll('_', ' ')}
    </span>
  );
}
