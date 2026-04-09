import type { Event, Occurrence } from './api';

export interface CalendarEvent {
  title: string;
  start: Date;
  end: Date;
  allDay: boolean;
  resource: {
    event: Event;
    occurrence: Occurrence;
    isCancelled: boolean;
    isMoved: boolean;
  };
}
