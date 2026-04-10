import { useState } from 'react';
import DatePicker from 'react-datepicker';
import 'react-datepicker/dist/react-datepicker.css';
import { createOccurrence } from '../../api/occurrences';
import type { Event, Occurrence, OccurrenceInput } from '../../types/api';
import './EventForm.css';
import './OccurrenceForm.css';

interface OccurrenceFormProps {
  events: Event[];
  onSuccess: (occurrence: Occurrence) => void;
  onCancel: () => void;
}

export function OccurrenceForm({ events, onSuccess, onCancel }: OccurrenceFormProps) {
  const now = new Date();
  const later = new Date(now.getTime() + 60 * 60 * 1000);

  const [eventId, setEventId] = useState(events[0]?.eventId ?? '');
  const [startTime, setStartTime] = useState<Date>(now);
  const [endTime, setEndTime] = useState<Date | null>(later);
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
        startTime: startTime.toISOString(),
        endTime: endTime ? endTime.toISOString() : undefined,
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
        <label>Start</label>
        <DatePicker
          selected={startTime}
          onChange={(date: Date | null) => date && setStartTime(date)}
          showTimeSelect
          timeFormat="HH:mm"
          timeIntervals={15}
          dateFormat="dd/MM/yyyy HH:mm"
          withPortal
          portalId="datepicker-portal"
          required
        />
      </div>

      <div className="EventForm__field">
        <label>End (optional)</label>
        <DatePicker
          selected={endTime}
          onChange={(date: Date | null) => setEndTime(date)}
          showTimeSelect
          timeFormat="HH:mm"
          timeIntervals={15}
          dateFormat="dd/MM/yyyy HH:mm"
          withPortal
          portalId="datepicker-portal"
          isClearable
          placeholderText="No end time"
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
