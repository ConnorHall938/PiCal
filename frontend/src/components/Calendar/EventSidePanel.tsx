import { useState } from 'react';
import type { Event, Occurrence } from '../../types/api';
import type { CalendarEvent } from '../../types/calendar';
import { EventDetails } from './EventDetails';
import { EventForm } from './EventForm';
import { OccurrenceForm } from './OccurrenceForm';
import './EventSidePanel.css';

type FormMode = 'event' | 'occurrence';

interface EventSidePanelProps {
  open: boolean;
  /** When set, shows details for this event instead of the create forms. */
  selectedCalEvent: CalendarEvent | null;
  events: Event[];
  onClose: () => void;
  onEventCreated: (event: Event) => void;
  onOccurrenceCreated: (occurrence: Occurrence) => void;
}

export function EventSidePanel({
  open,
  selectedCalEvent,
  events,
  onClose,
  onEventCreated,
  onOccurrenceCreated,
}: EventSidePanelProps) {
  const [formMode, setFormMode] = useState<FormMode>('event');

  const isDetails = selectedCalEvent !== null;
  const title = isDetails ? 'Details' : 'New';

  return (
    <div className={`EventSidePanel${open ? ' open' : ''}`}>
      <div className="EventSidePanel__inner">
        <div className="EventSidePanel__header">
          <span className="EventSidePanel__title">{title}</span>
          <button className="EventSidePanel__close" onClick={onClose} aria-label="Close panel">
            ×
          </button>
        </div>

        {!isDetails && (
          <div className="EventSidePanel__modes">
            <button
              className={`EventSidePanel__mode-btn${formMode === 'event' ? ' active' : ''}`}
              onClick={() => setFormMode('event')}
            >
              Event
            </button>
            <button
              className={`EventSidePanel__mode-btn${formMode === 'occurrence' ? ' active' : ''}`}
              onClick={() => setFormMode('occurrence')}
            >
              Occurrence
            </button>
          </div>
        )}

        <div className="EventSidePanel__body">
          {isDetails ? (
            <EventDetails calEvent={selectedCalEvent} />
          ) : formMode === 'event' ? (
            <EventForm onSuccess={onEventCreated} onCancel={onClose} />
          ) : (
            <OccurrenceForm events={events} onSuccess={onOccurrenceCreated} onCancel={onClose} />
          )}
        </div>
      </div>
    </div>
  );
}
