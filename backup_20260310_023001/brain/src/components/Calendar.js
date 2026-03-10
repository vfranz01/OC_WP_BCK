'use client'; // WICHTIG für Next.js 13+ (Client-Komponente)
import FullCalendar from "@fullcalendar/react";
import dayGridPlugin from "@fullcalendar/daygrid";
import timeGridPlugin from "@fullcalendar/timegrid";
import { useState } from "react";

export default function Calendar() {
  const [events] = useState([
    { title: "Test-Event", start: new Date() },
  ]);

  return (
    <div className="calendar-container">
      <h2>📅 German Club Cairns - Kalender</h2>
      <FullCalendar
        plugins={[dayGridPlugin, timeGridPlugin]}
        initialView="dayGridMonth"
        events={events}
        height="auto"
      />
    </div>
  );
}
