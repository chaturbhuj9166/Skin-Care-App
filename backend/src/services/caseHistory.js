const prisma = require('../config/db');

// Appends one entry to a case's status timeline. Called alongside every
// status-changing write (case creation, assignment, manual status update,
// solution submission) so the admin dashboard can render a full history.
function recordCaseStatus({ caseId, status, changedByType, changedById, note }) {
  return prisma.caseStatusHistory.create({
    data: { caseId, status, changedByType, changedById, note: note || null },
  });
}

module.exports = { recordCaseStatus };
