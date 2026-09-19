const test = require('node:test');
const assert = require('node:assert/strict');
const { buildCaseFilter } = require('../src/utils/caseFilter');
const { toCsv } = require('../src/utils/csv');

test('buildCaseFilter combines status, doctor, date range and user search', () => {
  const where = buildCaseFilter({
    status: 'ASSIGNED',
    doctorId: 'doc-1',
    search: 'simran',
    from: '2026-01-01',
    to: '2026-02-01',
  });

  assert.equal(where.status, 'ASSIGNED');
  assert.equal(where.doctorId, 'doc-1');
  assert.deepEqual(where.createdAt.gte, new Date('2026-01-01'));
  assert.deepEqual(where.createdAt.lte, new Date('2026-02-01'));
  assert.deepEqual(where.user.OR, [
    { name: { contains: 'simran', mode: 'insensitive' } },
    { phone: { contains: 'simran', mode: 'insensitive' } },
  ]);
});

test('buildCaseFilter omits unset fields entirely', () => {
  const where = buildCaseFilter({});
  assert.deepEqual(where, {});
});

test('toCsv quotes cells and escapes embedded quotes', () => {
  const csv = toCsv(['Name', 'Note'], [['Simran "S" Kaur', 'ok'], [null, undefined]]);
  const lines = csv.split('\n');
  assert.equal(lines[0], '"Name","Note"');
  assert.equal(lines[1], '"Simran ""S"" Kaur","ok"');
  assert.equal(lines[2], '"",""');
});
