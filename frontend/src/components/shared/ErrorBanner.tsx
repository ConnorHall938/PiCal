import './ErrorBanner.css';

interface ErrorBannerProps {
  message: string;
  onRetry?: () => void;
}

export function ErrorBanner({ message, onRetry }: ErrorBannerProps) {
  return (
    <div className="ErrorBanner">
      <span className="ErrorBanner__message">{message}</span>
      {onRetry && (
        <button className="ErrorBanner__retry" onClick={onRetry}>
          Retry
        </button>
      )}
    </div>
  );
}
