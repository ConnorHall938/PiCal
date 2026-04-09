import { useState } from 'react';
import type { Blind } from '../../types/api';
import './BlindCard.css';

interface BlindCardProps {
  blind: Blind;
  onOpen: (id: string) => Promise<void>;
  onClose: (id: string) => Promise<void>;
}

export function BlindCard({ blind, onOpen, onClose }: BlindCardProps) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handle(action: (id: string) => Promise<void>) {
    setBusy(true);
    setError(null);
    try {
      await action(blind.id);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Action failed');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="BlindCard">
      <div className="BlindCard__header">
        <span className="BlindCard__name">{blind.name}</span>
        <span
          className={`BlindCard__status ${
            blind.isOpen ? 'BlindCard__status--open' : 'BlindCard__status--closed'
          }`}
        >
          {blind.isOpen ? 'Open' : 'Closed'}
        </span>
      </div>
      <div className="BlindCard__actions">
        <button
          className="BlindCard__btn BlindCard__btn--open"
          disabled={busy || blind.isOpen}
          onClick={() => handle(onOpen)}
        >
          Open
        </button>
        <button
          className="BlindCard__btn BlindCard__btn--close"
          disabled={busy || !blind.isOpen}
          onClick={() => handle(onClose)}
        >
          Close
        </button>
      </div>
      {error && <span className="BlindCard__error">{error}</span>}
    </div>
  );
}
