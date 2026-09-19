export function Loading({ label = 'Loading…' }) {
  return <div className="py-12 text-center text-sm text-slate-400">{label}</div>;
}

export function ErrorMessage({ message }) {
  if (!message) return null;
  return (
    <div className="rounded-btn border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-600">
      {message}
    </div>
  );
}
