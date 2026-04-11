import type { Blind } from '../types/api';
import { fetchJSON } from './client';


export function listBlinds(): Promise<Blind[]> {
  return fetchJSON<Blind[]>('/blinds');
}

export async function openBlind(id: string): Promise<void> {
  const res = await fetch(`/blinds/${id}/open`, { method: 'POST' });
  if (!res.ok) throw new Error(`Failed to open blind: ${res.status}`);
}

export async function closeBlind(id: string): Promise<void> {
  const res = await fetch(`/blinds/${id}/close`, { method: 'POST' });
  if (!res.ok) throw new Error(`Failed to close blind: ${res.status}`);
}
