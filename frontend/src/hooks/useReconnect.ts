import { useEffect, useRef } from 'react';

export function useReconnect(intervalMs = 5000): void {
  const wasOffline = useRef(false);
  const failCount = useRef(0);

  useEffect(() => {
    const id = setInterval(async () => {
      try {
        const res = await fetch('/health');
        if (res.ok) {
          if (wasOffline.current) window.location.reload();
          failCount.current = 0;
          wasOffline.current = false;
        } else {
          failCount.current++;
          // Require 2 consecutive failures to avoid spurious reloads
          if (failCount.current >= 2) wasOffline.current = true;
        }
      } catch {
        failCount.current++;
        if (failCount.current >= 2) wasOffline.current = true;
      }
    }, intervalMs);
    return () => clearInterval(id);
  }, [intervalMs]);
}
