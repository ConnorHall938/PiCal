import dayjs from 'dayjs';
import type { View } from 'react-big-calendar';
import './CalendarToolbar.css';

interface CalendarToolbarProps {
  view: View;
  date: Date;
  onViewChange: (v: View) => void;
  onNavigate: (d: Date) => void;
  onAddClick: () => void;
}

function formatDate(date: Date, view: View): string {
  const d = dayjs(date);
  if (view === 'month') return d.format('MMMM YYYY');
  if (view === 'week') {
    const start = d.startOf('week');
    const end = d.endOf('week');
    if (start.month() === end.month()) return start.format('MMMM D') + ' – ' + end.format('D, YYYY');
    return start.format('MMM D') + ' – ' + end.format('MMM D, YYYY');
  }
  return d.format('dddd, MMMM D, YYYY');
}

function navigate(date: Date, view: View, direction: -1 | 1): Date {
  const d = dayjs(date);
  if (view === 'month') return d.add(direction, 'month').toDate();
  if (view === 'week') return d.add(direction * 7, 'day').toDate();
  return d.add(direction, 'day').toDate();
}

export function CalendarToolbar({
  view,
  date,
  onViewChange,
  onNavigate,
  onAddClick,
}: CalendarToolbarProps) {
  return (
    <div className="CalendarToolbar">
      <div className="CalendarToolbar__views">
        {(['month', 'week', 'day'] as View[]).map((v) => (
          <button
            key={v}
            className={`CalendarToolbar__view-btn${view === v ? ' active' : ''}`}
            onClick={() => onViewChange(v)}
          >
            {v.charAt(0).toUpperCase() + v.slice(1)}
          </button>
        ))}
      </div>

      <div className="CalendarToolbar__nav">
        <button
          className="CalendarToolbar__nav-btn"
          onClick={() => onNavigate(navigate(date, view, -1))}
          aria-label="Previous"
        >
          ‹
        </button>
        <button
          className="CalendarToolbar__today-btn"
          onClick={() => onNavigate(new Date())}
        >
          Today
        </button>
        <button
          className="CalendarToolbar__nav-btn"
          onClick={() => onNavigate(navigate(date, view, 1))}
          aria-label="Next"
        >
          ›
        </button>
      </div>

      <span className="CalendarToolbar__date">{formatDate(date, view)}</span>

      <button className="CalendarToolbar__add-btn" onClick={onAddClick} aria-label="Add event">
        +
      </button>
    </div>
  );
}
