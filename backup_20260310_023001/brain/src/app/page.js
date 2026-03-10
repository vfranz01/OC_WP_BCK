// src/app/page.js
import Calendar from '../components/Calendar';

export default function Home() {
  return (
    <div className="dashboard">
      <h1>🧠 Brain Dashboard</h1>
      <div className="calendar-section">
        <Calendar />
      </div>
    </div>
  );
}
