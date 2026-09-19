export default function Field({ label, children }) {
  return (
    <label className="mb-3 block text-sm">
      <span className="mb-1 block font-medium text-slate-600">{label}</span>
      {children}
    </label>
  );
}

const FIELD_CLASSES =
  'w-full rounded-xl border border-slate-200 bg-slate-50 px-3 py-2.5 text-sm text-slate-800 outline-none transition-colors focus:border-brand-teal focus:bg-white focus:ring-1 focus:ring-brand-teal';

export function TextInput(props) {
  return <input {...props} className={`${FIELD_CLASSES} ${props.className || ''}`} />;
}

export function TextArea(props) {
  return <textarea {...props} className={`${FIELD_CLASSES} ${props.className || ''}`} />;
}

export function Select({ children, ...props }) {
  return (
    <select {...props} className={`${FIELD_CLASSES} ${props.className || ''}`}>
      {children}
    </select>
  );
}
