// Minimal CSV serializer: quotes every cell and doubles embedded quotes,
// which is enough for the simple flat rows the admin export endpoints emit.
function toCsv(header, rows) {
  const escape = (value) => `"${String(value ?? '').replace(/"/g, '""')}"`;
  return [header, ...rows].map((row) => row.map(escape).join(',')).join('\n');
}

module.exports = { toCsv };
