import { AnimatePresence, motion } from 'framer-motion';
import { CheckCircle2, XCircle } from 'lucide-react';
import { useToastStore } from '../store/toastStore';

export default function ToastContainer() {
  const toasts = useToastStore((s) => s.toasts);
  const dismiss = useToastStore((s) => s.dismiss);

  return (
    <div className="pointer-events-none fixed bottom-4 right-4 z-[100] flex flex-col gap-2 sm:bottom-6 sm:right-6">
      <AnimatePresence>
        {toasts.map((t) => (
          <motion.div
            key={t.id}
            initial={{ opacity: 0, y: 12, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, x: 24 }}
            transition={{ duration: 0.2 }}
            onClick={() => dismiss(t.id)}
            className={`pointer-events-auto flex max-w-xs items-start gap-2.5 rounded-xl border px-4 py-3 text-sm shadow-lg backdrop-blur-sm ${
              t.type === 'error'
                ? 'border-red-200 bg-red-50/95 text-red-700'
                : 'border-green-200 bg-green-50/95 text-green-700'
            }`}
          >
            {t.type === 'error' ? <XCircle className="mt-0.5 h-4 w-4 flex-shrink-0" /> : <CheckCircle2 className="mt-0.5 h-4 w-4 flex-shrink-0" />}
            <span className="font-medium">{t.message}</span>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
