export interface Event {
  eventId: string;
  personName: string;
  title: string;
  notes?: string;
  timezone: string;
  allDay: boolean;
  rrule?: string;
}

export interface EventInput {
  personName: string;
  title: string;
  notes?: string;
  timezone: string;
  allDay: boolean;
  rrule?: string;
}

export type OccurrenceKind = 0 | 1 | 2; // 0=normal, 1=moved, 2=cancelled

export interface Occurrence {
  occurrenceId: string;
  eventId: string;
  startTime: string;
  endTime?: string;
  moved: OccurrenceKind;
  newStartTime?: string;
  newEndTime?: string;
}

export interface OccurrenceInput {
  eventId: string;
  startTime: string;
  endTime?: string;
}

export interface Blind {
  id: string;
  name: string;
}

export interface PagedResponse<T> {
  items: T[];
  limit: number;
  offset: number;
  count: number;
  total: number;
}
