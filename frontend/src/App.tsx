import { useState } from 'react'
import './App.css'

type ViewMode = "day" | "week" | "month";

function App() {
const [viewMode, setViewMode] = useState<ViewMode>("month");

  return (
    <div className="AppShell">
      <main className="CalendarPane">
        <header className="Toolbar">
          <h1 className="Title">PiCal</h1>

          <div className="ViewButtons">
            <button
              className={viewMode === "day" ? "active" : ""}
              onClick={() => setViewMode("day")}
            >
              Day
            </button>
            <button
              className={viewMode === "week" ? "active" : ""}
              onClick={() => setViewMode("week")}
            >
              Week
            </button>
            <button
              className={viewMode === "month" ? "active" : ""}
              onClick={() => setViewMode("month")}
            >
              Month
            </button>
          </div>
        </header>

        <div className="CalendarSurface">
          <div className="CalendarDayBox">
            Currently showing: <b>{viewMode}</b>
          </div>
        </div>
      </main>

      <aside className="RightPane">
        <h2>Right panel</h2>
        <p>Reserved for now.</p>
      </aside>
    </div>
  );
}

export default App
