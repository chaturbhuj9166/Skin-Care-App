import { useCallback, useEffect, useState } from 'react';
import { apiErrorMessage } from '../lib/api';

// Small fetch-on-mount(+deps) hook shared by every list/detail page, so pages
// don't each hand-roll loading/error/data state around an axios call.
export function useApiQuery(fetcher, deps = []) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const refetch = useCallback(() => {
    setLoading(true);
    setError(null);
    return fetcher()
      .then((res) => setData(res.data))
      .catch((err) => setError(apiErrorMessage(err)))
      .finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  useEffect(() => {
    refetch();
  }, [refetch]);

  return { data, loading, error, refetch, setData };
}
