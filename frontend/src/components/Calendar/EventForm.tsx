import { useState } from 'react';
import { createEvent } from '../../api/events';
import type { Event, EventInput } from '../../types/api';
import './EventForm.css';

interface EventFormProps {
  onSuccess: (event: Event) => void;
  onCancel: () => void;
}

export function EventForm({ onSuccess, onCancel }: EventFormProps) {
  const defaultTz = Intl.DateTimeFormat().resolvedOptions().timeZone;

  const [fields, setFields] = useState<EventInput>({
    personName: '',
    title: '',
    notes: '',
    timezone: defaultTz,
    allDay: false,
    rrule: '',
  });
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function set<K extends keyof EventInput>(key: K, value: EventInput[K]) {
    setFields((prev) => ({ ...prev, [key]: value }));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      const input: EventInput = {
        ...fields,
        notes: fields.notes || undefined,
        rrule: fields.rrule || undefined,
      };
      const created = await createEvent(input);
      onSuccess(created);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to create event');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form className="EventForm" onSubmit={handleSubmit}>
      <div className="EventForm__field">
        <label htmlFor="ef-person">Person</label>
        <input
          id="ef-person"
          type="text"
          value={fields.personName}
          onChange={(e) => set('personName', e.target.value)}
          placeholder="Name"
          required
        />
      </div>
      <div className="EventForm__field">
        <label htmlFor="ef-title">Title</label>
        <input
          id="ef-title"
          type="text"
          value={fields.title}
          onChange={(e) => set('title', e.target.value)}
          placeholder="Event title"
          required
        />
      </div>
      <div className="EventForm__field">
        <label htmlFor="ef-notes">Notes</label>
        <textarea
          id="ef-notes"
          value={fields.notes}
          onChange={(e) => set('notes', e.target.value)}
          placeholder="Optional notes"
        />
      </div>
      <div className="EventForm__field">
        <label htmlFor="ef-tz">Timezone</label>
        <input
          id="ef-tz"
          type="text"
          value={fields.timezone}
          onChange={(e) => set('timezone', e.target.value)}
          required
        />
      </div>
      <div className="EventForm__field">
        <div className="EventForm__checkbox-row">
          <input
            id="ef-allday"
            type="checkbox"
            checked={fields.allDay}
            onChange={(e) => set('allDay', e.target.checked)}
          />
          <label htmlFor="ef-allday">All day</label>
        </div>
      </div>
      <div className="EventForm__field">
        <label htmlFor="ef-rrule">Recurrence (RRule)</label>
        <input
          id="ef-rrule"
          type="text"
          value={fields.rrule}
          onChange={(e) => set('rrule', e.target.value)}
          placeholder="e.g. FREQ=WEEKLY;BYDAY=MO"
        />
      </div>
      {error && <span className="EventForm__error">{error}</span>}
      <div className="EventForm__actions">
        <button type="submit" className="EventForm__submit" disabled={submitting}>
          {submitting ? 'Saving…' : 'Create Event'}
        </button>
        <button type="button" className="EventForm__cancel" onClick={onCancel}>
          Cancel
        </button>
      </div>
    </form>
  );
}
