import type { Event, EventInput } from '../types/api';
import { fetchAll, fetchJSON } from './client';

export function listEvents(): Promise<Event[]> {
  return fetchAll<Event>('/events');
}

export function createEvent(input: EventInput): Promise<Event> {
  return fetchJSON<Event>('/events', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(input),
  });
}
