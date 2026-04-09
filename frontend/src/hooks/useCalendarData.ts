import { useCallback, useEffect, useState } from 'react';
import { listEvents } from '../api/events';
import { listOccurrences } from '../api/occurrences';
import type { Event } from '../types/api';
import type { CalendarEvent } from '../types/calendar';

export interface CalendarDataResult {
  calendarEvents: CalendarEvent[];
  events: Event[];
  loading: boolean;
  error: string | null;
  reload: () => void;
}

export function useCalendarData(): CalendarDataResult {
  const [calendarEvents, setCalendarEvents] = useState<CalendarEvent[]>([]);
  const [events, setEvents] = useState<Event[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [tick, setTick] = useState(0);

  const reload = useCallback(() => setTick((t) => t + 1), []);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    Promise.all([listEvents(), listOccurrences()])
      .then(([evts, occs]) => {
        if (cancelled) return;

        setEvents(evts);

        const evtMap = new Map<string, Event>();
        for (const e of evts) evtMap.set(e.eventId, e);

        const mapped: CalendarEvent[] = [];
        for (const occ of occs) {
          const evt = evtMap.get(occ.eventId);
          if (!evt) continue;

          const isCancelled = occ.moved === 2;
          const isMoved = occ.moved === 1;

          const startStr = isMoved && occ.newStartTime ? occ.newStartTime : occ.startTime;
          const endStr = isMoved && occ.newEndTime
            ? occ.newEndTime
            : occ.endTime;

          const start = new Date(startStr);
          const end = endStr
            ? new Date(endStr)
            : new Date(start.getTime() + 60 * 60 * 1000);

          mapped.push({
            title: evt.title,
            start,
            end,
            allDay: evt.allDay,
            resource: { event: evt, occurrence: occ, isCancelled, isMoved },
          });
        }

        setCalendarEvents(mapped);
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : 'Failed to load calendar data');
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [tick]);

  return { calendarEvents, events, loading, error, reload };
}
