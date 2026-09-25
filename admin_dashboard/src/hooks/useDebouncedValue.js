import { useEffect, useState } from 'react';

// Delays a fast-changing value (a search box) so list pages fire one request
// once typing settles instead of one per keystroke.
export function useDebouncedValue(value, delay = 300) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debounced;
}
