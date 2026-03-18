// Calendar Widget for Noctalia
const style = `
  <style>
    .calendar-container {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: rgba(30, 30, 30, 0.8);
      color: white;
      padding: 15px;
      border-radius: 12px;
      width: 250px;
    }
    .calendar-header {
      text-align: center;
      font-weight: bold;
      margin-bottom: 10px;
      font-size: 1.2em;
    }
    .calendar-grid {
      display: grid;
      grid-template-columns: repeat(7, 1fr);
      gap: 5px;
      text-align: center;
    }
    .day-name {
      font-size: 0.8em;
      color: #aaa;
      margin-bottom: 5px;
    }
    .day {
      padding: 5px 0;
      border-radius: 4px;
    }
    .today {
      background-color: #0078d4;
      color: white;
      font-weight: bold;
    }
    .empty {
      visibility: hidden;
    }
  </style>
`;

function generateCalendar() {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth();
  const today = now.getDate();

  const monthNames = ["January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"];
  
  const firstDay = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();

  let html = `<div class="calendar-container">`;
  html += `<div class="calendar-header">${monthNames[month]} ${year}</div>`;
  html += `<div class="calendar-grid">`;

  // Add Day Headers
  ['S', 'M', 'T', 'W', 'T', 'F', 'S'].forEach(d => {
    html += `<div class="day-name">${d}</div>`;
  });

  // Fill empty slots for first week
  for (let i = 0; i < firstDay; i++) {
    html += `<div class="day empty"></div>`;
  }

  // Fill days
  for (let day = 1; day <= daysInMonth; day++) {
    const isToday = day === today ? 'today' : '';
    html += `<div class="day ${isToday}">${day}</div>`;
  }

  html += `</div></div>`;
  return style + html;
}

// noctalia plugin entry point
export function onInit(context) {
  context.setHtml(generateCalendar());
}
