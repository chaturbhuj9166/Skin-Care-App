export default function Card({ className = '', children, ...props }) {
  return (
    <div className={`rounded-2xl bg-white border border-slate-200 shadow-sm p-5 ${className}`} {...props}>
      {children}
    </div>
  );
}
