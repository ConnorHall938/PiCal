import type { PagedResponse } from '../types/api';

export class ApiError extends Error {
  readonly status: number;
  constructor(status: number, message: string) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

export async function fetchJSON<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, init);
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new ApiError(res.status, text);
  }
  return res.json() as Promise<T>;
}

export async function fetchAll<T>(path: string): Promise<T[]> {
  const results: T[] = [];
  let offset = 0;
  const limit = 200;

  while (true) {
    const sep = path.includes('?') ? '&' : '?';
    const page = await fetchJSON<PagedResponse<T>>(
      `${path}${sep}limit=${limit}&offset=${offset}`,
    );
    results.push(...page.items);
    offset += page.count;
    if (offset >= page.total) break;
  }

  return results;
}
