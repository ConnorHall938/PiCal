import { useCallback, useEffect, useState } from 'react';
import { closeBlind, listBlinds, openBlind } from '../api/blinds';
import type { Blind } from '../types/api';

export interface BlindsResult {
  blinds: Blind[];
  loading: boolean;
  error: string | null;
  open: (id: string) => Promise<void>;
  close: (id: string) => Promise<void>;
  reload: () => void;
}

export function useBlinds(): BlindsResult {
  const [blinds, setBlinds] = useState<Blind[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [tick, setTick] = useState(0);

  const reload = useCallback(() => setTick((t) => t + 1), []);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    listBlinds()
      .then((data) => {
        if (!cancelled) setBlinds(data);
      })
      .catch((err: unknown) => {
        if (!cancelled)
          setError(err instanceof Error ? err.message : 'Failed to load blinds');
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [tick]);

  const open = useCallback(async (id: string) => {
    await openBlind(id);
  }, []);

  const close = useCallback(async (id: string) => {
    await closeBlind(id);
  }, []);

  return { blinds, loading, error, open, close, reload };
}
