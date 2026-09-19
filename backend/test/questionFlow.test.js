const test = require('node:test');
const assert = require('node:assert/strict');
const { createQuestionFlowSchema, updateQuestionFlowSchema } = require('../src/validation/questionFlow');
const { validateAnswers } = require('../src/validation/questionFlow');

test('preserves optional questions, IDs and question order on a builder save', () => {
  const input = { title: 'Intake', questions: [
    { id: 'second', text: 'Anything else?', type: 'text', required: false },
    { id: 'first', text: 'Concern?', type: 'single_choice', required: true, options: ['Acne', 'Other'] },
  ] };
  assert.deepEqual(createQuestionFlowSchema.parse(input), input);
});

test('assigns distinct IDs to new questions and defaults required to true', () => {
  const result = createQuestionFlowSchema.parse({ title: 'Intake', questions: [
    { text: 'First', type: 'text' }, { text: 'Second', type: 'rating' },
  ] });
  assert.ok(result.questions.every(q => q.id && q.required));
  assert.notEqual(result.questions[0].id, result.questions[1].id);
});

test('accepts all six specified types', () => {
  for (const type of ['text', 'multiple_choice', 'single_choice', 'yes_no', 'rating', 'photo_upload']) {
    assert.equal(createQuestionFlowSchema.safeParse({ title: 'Intake', questions: [
      { text: 'Question', type, options: ['One', 'Two'] },
    ] }).success, true);
  }
});

test('rejects unknown types, blank copy, invalid choice options and duplicate IDs', () => {
  const base = { id: 'q1', text: 'Concern?', type: 'text' };
  for (const questions of [
    [{ ...base, type: 'unsupported' }], [{ ...base, text: '  ' }],
    [{ ...base, type: 'single_choice' }],
    [{ ...base, type: 'multiple_choice', options: ['One'] }],
    [{ ...base, type: 'single_choice', options: ['One', ' One '] }],
    [base, base],
  ]) {
    assert.equal(createQuestionFlowSchema.safeParse({ title: 'Intake', questions }).success, false);
  }
});

test('activation-only updates are supported but empty questionnaires are rejected', () => {
  assert.deepEqual(updateQuestionFlowSchema.parse({ isActive: true }), { isActive: true });
  assert.equal(updateQuestionFlowSchema.safeParse({ questions: [] }).success, false);
});

test('validates all answer types and accepts false for a required yes/no question', () => {
  const questions = [
    { id: 'text', type: 'text' },
    { id: 'single', type: 'single_choice', options: ['Acne', 'Other'] },
    { id: 'multiple', type: 'multiple_choice', options: ['Dry', 'Sensitive'] },
    { id: 'yes', type: 'yes_no' }, { id: 'rating', type: 'rating' },
    { id: 'photo', type: 'photo_upload' }, { id: 'optional', type: 'text', required: false },
  ];
  const answers = { text: 'Details', single: 'Acne', multiple: ['Dry', 'Sensitive'],
    yes: false, rating: 3, photo: ['https://example.com/photo.jpg'] };
  assert.deepEqual(validateAnswers(questions, answers), []);
  for (const [key, value] of Object.entries({ text: '  ', single: 'Unknown', multiple: ['Dry', 'Dry'],
    yes: 'false', rating: 6, photo: ['invalid'] })) {
    assert.ok(validateAnswers(questions, { ...answers, [key]: value }).length > 0, key);
  }
  assert.ok(validateAnswers(questions, { ...answers, unexpected: 'extra' }).length > 0);
  assert.ok(validateAnswers(questions, null).length > 0);
  assert.ok(validateAnswers(questions, []).length > 0);
});
