import { useState } from 'react';
import './App.css';
import { CalendarTab } from './components/Calendar/CalendarTab';
import { BlindsTab } from './components/Blinds/BlindsTab';
import { TabBar, type Tab } from './components/TabBar/TabBar';
import { useReconnect } from './hooks/useReconnect';

function App() {
  useReconnect();
  const [activeTab, setActiveTab] = useState<Tab>('calendar');

  return (
    <div className="AppShell">
      <TabBar activeTab={activeTab} onTabChange={setActiveTab} />
      <div className="AppShell__content">
        <div className={`AppShell__tab${activeTab !== 'calendar' ? ' AppShell__tab--hidden' : ''}`}>
          <CalendarTab />
        </div>
        <div className={`AppShell__tab${activeTab !== 'blinds' ? ' AppShell__tab--hidden' : ''}`}>
          <BlindsTab />
        </div>
      </div>
    </div>
  );
}

export default App;
