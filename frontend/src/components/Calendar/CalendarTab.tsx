import { useState } from 'react';
import type { View } from 'react-big-calendar';
import { useCalendarData } from '../../hooks/useCalendarData';
import type { CalendarEvent } from '../../types/calendar';
import { ErrorBanner } from '../shared/ErrorBanner';
import { LoadingSpinner } from '../shared/LoadingSpinner';
import { CalendarToolbar } from './CalendarToolbar';
import { CalendarView } from './CalendarView';
import { EventSidePanel } from './EventSidePanel';
import './CalendarTab.css';

export function CalendarTab() {
  const { calendarEvents, events, loading, error, reload } = useCalendarData();
  const [view, setView] = useState<View>('month');
  const [date, setDate] = useState(new Date());
  const [panelOpen, setPanelOpen] = useState(false);
  const [selectedCalEvent, setSelectedCalEvent] = useState<CalendarEvent | null>(null);

  function openNew() {
    setSelectedCalEvent(null);
    setPanelOpen(true);
  }

  function handleSelectEvent(calEvent: CalendarEvent) {
    setSelectedCalEvent(calEvent);
    setPanelOpen(true);
  }

  function closePanel() {
    setPanelOpen(false);
    setSelectedCalEvent(null);
  }

  return (
    <div className="CalendarTab">
      <div className="CalendarTab__main">
        <CalendarToolbar
          view={view}
          date={date}
          onViewChange={setView}
          onNavigate={setDate}
          onAddClick={openNew}
        />
        {loading && <LoadingSpinner />}
        {!loading && error && (
          <div className="CalendarTab__error">
            <ErrorBanner message={error} onRetry={reload} />
          </div>
        )}
        {!loading && !error && (
          <CalendarView
            events={calendarEvents}
            view={view}
            date={date}
            onNavigate={setDate}
            onView={setView}
            onSelectEvent={handleSelectEvent}
          />
        )}
      </div>
      <EventSidePanel
        open={panelOpen}
        selectedCalEvent={selectedCalEvent}
        events={events}
        onClose={closePanel}
        onEventCreated={() => {
          closePanel();
          reload();
        }}
        onOccurrenceCreated={() => {
          closePanel();
          reload();
        }}
      />
    </div>
  );
}
