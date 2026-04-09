import type { Occurrence, OccurrenceInput } from '../types/api';
import { fetchAll, fetchJSON } from './client';

export function listOccurrences(): Promise<Occurrence[]> {
  return fetchAll<Occurrence>('/occurrences');
}

export function createOccurrence(input: OccurrenceInput): Promise<Occurrence> {
  return fetchJSON<Occurrence>('/occurrences', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(input),
  });
}
