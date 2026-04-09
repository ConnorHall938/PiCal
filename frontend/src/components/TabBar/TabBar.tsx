import './TabBar.css';

export type Tab = 'calendar' | 'blinds';

interface TabBarProps {
  activeTab: Tab;
  onTabChange: (tab: Tab) => void;
}

export function TabBar({ activeTab, onTabChange }: TabBarProps) {
  return (
    <nav className="TabBar">
      <button
        className={`TabBar__tab${activeTab === 'calendar' ? ' active' : ''}`}
        onClick={() => onTabChange('calendar')}
      >
        Calendar
      </button>
      <button
        className={`TabBar__tab${activeTab === 'blinds' ? ' active' : ''}`}
        onClick={() => onTabChange('blinds')}
      >
        Blinds
      </button>
    </nav>
  );
}
