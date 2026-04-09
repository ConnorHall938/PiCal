import type { Blind } from '../types/api';
import { fetchJSON } from './client';

export function listBlinds(): Promise<Blind[]> {
  return fetchJSON<Blind[]>('/blinds');
}

export function openBlind(id: string): Promise<Blind> {
  return fetchJSON<Blind>(`/blinds/${id}/open`, { method: 'POST' });
}

export function closeBlind(id: string): Promise<Blind> {
  return fetchJSON<Blind>(`/blinds/${id}/close`, { method: 'POST' });
}
