// The monthly case query only returns months that actually have rows, so a
// quiet month simply disappears from the dashboard chart. This pads the
// series back out to a fixed window of consecutive months.
function fillMonthlySeries(rows, start, months) {
  const counts = new Map(rows.map((row) => [row.month, row.count]));

  return Array.from({ length: months }, (_, i) => {
    const date = new Date(start.getFullYear(), start.getMonth() + i, 1);
    const month = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
    return { month, count: counts.get(month) || 0 };
  });
}

module.exports = { fillMonthlySeries };
