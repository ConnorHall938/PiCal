import dayjs from 'dayjs';
import { Calendar, dayjsLocalizer, type View } from 'react-big-calendar';
import 'react-big-calendar/lib/css/react-big-calendar.css';
import type { CalendarEvent } from '../../types/calendar';
import './CalendarView.css';

const localizer = dayjsLocalizer(dayjs);

interface CalendarViewProps {
  events: CalendarEvent[];
  view: View;
  date: Date;
  onNavigate: (date: Date) => void;
  onView: (view: View) => void;
  onSelectEvent: (event: CalendarEvent) => void;
}

function EventComponent({ event }: { event: CalendarEvent }) {
  return (
    <div className="CalEvent">
      <span className="CalEvent__title">{event.title}</span>
      <span className="CalEvent__person">{event.resource.event.personName}</span>
    </div>
  );
}

export function CalendarView({
  events,
  view,
  date,
  onNavigate,
  onView,
  onSelectEvent,
}: CalendarViewProps) {
  return (
    <div className="CalendarView">
      <Calendar<CalendarEvent>
        localizer={localizer}
        events={events}
        view={view}
        date={date}
        onNavigate={onNavigate}
        onView={onView}
        onSelectEvent={onSelectEvent}
        toolbar={false}
        components={{ event: EventComponent }}
        eventPropGetter={(event) => {
          const classes: string[] = [];
          if (event.resource.isCancelled) classes.push('event--cancelled');
          if (event.resource.isMoved) classes.push('event--moved');
          return { className: classes.join(' ') };
        }}
        style={{ height: '100%' }}
      />
    </div>
  );
}
