const test = require('node:test');
const assert = require('node:assert/strict');
const { generateCode, hashCode, codesMatch } = require('../src/services/otp');

test('generateCode always returns exactly six digits', () => {
  for (let i = 0; i < 500; i++) {
    assert.match(generateCode(), /^\d{6}$/);
  }
});

test('codesMatch accepts the right code for the right phone only', () => {
  const stored = hashCode('+919820000001', '042917');
  assert.equal(codesMatch('+919820000001', '042917', stored), true);
  assert.equal(codesMatch('+919820000001', '042918', stored), false);
  assert.equal(codesMatch('+919820000002', '042917', stored), false);
});

test('hashCode never stores the plain code', () => {
  const stored = hashCode('+919820000001', '123456');
  assert.ok(!stored.includes('123456'));
  assert.match(stored, /^[0-9a-f]{64}$/);
});
