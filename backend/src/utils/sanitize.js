// Strips the `password` field before an Admin/Doctor record is ever sent
// back in an API response.
function sanitize(record) {
  if (!record) return record;
  const { password, ...rest } = record;
  return rest;
}

module.exports = sanitize;
