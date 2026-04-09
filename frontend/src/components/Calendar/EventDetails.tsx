import dayjs from 'dayjs';
import type { CalendarEvent } from '../../types/calendar';
import './EventDetails.css';

interface EventDetailsProps {
  calEvent: CalendarEvent;
}

function fmt(date: Date, allDay: boolean): string {
  if (allDay) return dayjs(date).format('dddd, MMM D, YYYY');
  return dayjs(date).format('dddd, MMM D, YYYY [at] h:mm A');
}

export function EventDetails({ calEvent }: EventDetailsProps) {
  const { event, occurrence, isCancelled, isMoved } = calEvent.resource;

  // For moved occurrences, show both original and new times
  const originalStart = isMoved ? new Date(occurrence.startTime) : null;
  const originalEnd =
    isMoved && occurrence.endTime ? new Date(occurrence.endTime) : null;

  return (
    <div className="EventDetails">
      <h2 className="EventDetails__title">{event.title}</h2>

      <div className="EventDetails__badges">
        {isCancelled && (
          <span className="EventDetails__badge EventDetails__badge--cancelled">Cancelled</span>
        )}
        {isMoved && (
          <span className="EventDetails__badge EventDetails__badge--moved">Moved</span>
        )}
        {event.allDay && (
          <span className="EventDetails__badge EventDetails__badge--allday">All day</span>
        )}
      </div>

      <div className="EventDetails__table">
        <span className="EventDetails__label">Person</span>
        <span className="EventDetails__value">{event.personName}</span>

        <span className="EventDetails__label">Start</span>
        <span
          className={`EventDetails__value${isCancelled ? ' EventDetails__value--strikethrough' : ''}`}
        >
          {fmt(calEvent.start, event.allDay)}
        </span>

        {!event.allDay && (
          <>
            <span className="EventDetails__label">End</span>
            <span
              className={`EventDetails__value${isCancelled ? ' EventDetails__value--strikethrough' : ''}`}
            >
              {fmt(calEvent.end, event.allDay)}
            </span>
          </>
        )}

        {isMoved && originalStart && (
          <>
            <hr className="EventDetails__divider" />
            <span className="EventDetails__label">Was</span>
            <span className="EventDetails__value EventDetails__value--strikethrough">
              {fmt(originalStart, event.allDay)}
              {originalEnd && ` – ${fmt(originalEnd, event.allDay)}`}
            </span>
          </>
        )}

        {event.notes && (
          <>
            <hr className="EventDetails__divider" />
            <span className="EventDetails__label">Notes</span>
            <span className="EventDetails__value">{event.notes}</span>
          </>
        )}

        {event.rrule && (
          <>
            <span className="EventDetails__label">Recurs</span>
            <span className="EventDetails__value EventDetails__rrule">{event.rrule}</span>
          </>
        )}

        <hr className="EventDetails__divider" />
        <span className="EventDetails__label">Timezone</span>
        <span className="EventDetails__value">{event.timezone}</span>
      </div>
    </div>
  );
}
