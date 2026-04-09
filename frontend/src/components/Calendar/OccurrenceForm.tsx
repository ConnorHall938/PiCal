import { useState } from 'react';
import { createOccurrence } from '../../api/occurrences';
import type { Event, Occurrence, OccurrenceInput } from '../../types/api';
import './EventForm.css'; // reuse same styles

interface OccurrenceFormProps {
  events: Event[];
  onSuccess: (occurrence: Occurrence) => void;
  onCancel: () => void;
}

function toLocalDatetimeValue(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `T${pad(date.getHours())}:${pad(date.getMinutes())}`
  );
}

export function OccurrenceForm({ events, onSuccess, onCancel }: OccurrenceFormProps) {
  const now = new Date();
  const later = new Date(now.getTime() + 60 * 60 * 1000);

  const [eventId, setEventId] = useState(events[0]?.eventId ?? '');
  const [startTime, setStartTime] = useState(toLocalDatetimeValue(now));
  const [endTime, setEndTime] = useState(toLocalDatetimeValue(later));
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!eventId) {
      setError('Please select an event');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const input: OccurrenceInput = {
        eventId,
        startTime: new Date(startTime).toISOString(),
        endTime: endTime ? new Date(endTime).toISOString() : undefined,
      };
      const created = await createOccurrence(input);
      onSuccess(created);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to create occurrence');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form className="EventForm" onSubmit={handleSubmit}>
      <div className="EventForm__field">
        <label htmlFor="of-event">Event</label>
        <select
          id="of-event"
          value={eventId}
          onChange={(e) => setEventId(e.target.value)}
          required
        >
          {events.length === 0 && (
            <option value="" disabled>
              No events — create one first
            </option>
          )}
          {events.map((ev) => (
            <option key={ev.eventId} value={ev.eventId}>
              {ev.personName} — {ev.title}
            </option>
          ))}
        </select>
      </div>
      <div className="EventForm__field">
        <label htmlFor="of-start">Start</label>
        <input
          id="of-start"
          type="datetime-local"
          value={startTime}
          onChange={(e) => setStartTime(e.target.value)}
          required
        />
      </div>
      <div className="EventForm__field">
        <label htmlFor="of-end">End (optional)</label>
        <input
          id="of-end"
          type="datetime-local"
          value={endTime}
          onChange={(e) => setEndTime(e.target.value)}
        />
      </div>
      {error && <span className="EventForm__error">{error}</span>}
      <div className="EventForm__actions">
        <button type="submit" className="EventForm__submit" disabled={submitting || events.length === 0}>
          {submitting ? 'Saving…' : 'Create Occurrence'}
        </button>
        <button type="button" className="EventForm__cancel" onClick={onCancel}>
          Cancel
        </button>
      </div>
    </form>
  );
}
