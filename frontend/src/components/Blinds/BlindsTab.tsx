import { useBlinds } from '../../hooks/useBlinds';
import { ErrorBanner } from '../shared/ErrorBanner';
import { LoadingSpinner } from '../shared/LoadingSpinner';
import { BlindCard } from './BlindCard';
import './BlindsTab.css';

export function BlindsTab() {
  const { blinds, loading, error, open, close, reload } = useBlinds();

  if (loading) return <LoadingSpinner />;

  return (
    <div className="BlindsTab">
      {error && <ErrorBanner message={error} onRetry={reload} />}
      {!error && blinds.length === 0 && (
        <p className="BlindsTab__empty">No blinds configured.</p>
      )}
      <div className="BlindsTab__grid">
        {blinds.map((blind) => (
          <BlindCard key={blind.id} blind={blind} onOpen={open} onClose={close} />
        ))}
      </div>
    </div>
  );
}
