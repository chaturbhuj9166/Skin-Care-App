const { randomUUID } = require('node:crypto');
const { z } = require('zod');

const questionSchema = z.object({
  id: z.string().trim().min(1).default(() => randomUUID()),
  text: z.string().trim().min(1),
  type: z.enum(['text', 'multiple_choice', 'single_choice', 'yes_no', 'rating', 'photo_upload']),
  required: z.boolean().default(true),
  options: z.array(z.string().trim().min(1)).optional(),
}).superRefine((question, context) => {
  if (['single_choice', 'multiple_choice'].includes(question.type)) {
    if (!question.options || question.options.length < 2) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: ['options'], message: 'Choice questions need at least two options' });
    } else if (new Set(question.options).size !== question.options.length) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: ['options'], message: 'Choice options must be unique' });
    }
  }
});

const questionsSchema = z.array(questionSchema).min(1).superRefine((questions, context) => {
  const ids = new Set();
  questions.forEach((question, index) => {
    if (ids.has(question.id)) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: [index, 'id'], message: 'Question IDs must be unique' });
    }
    ids.add(question.id);
  });
});

const createQuestionFlowSchema = z.object({
  title: z.string().trim().min(1),
  questions: questionsSchema,
});

const updateQuestionFlowSchema = z.object({
  title: z.string().trim().min(1).optional(),
  questions: questionsSchema.optional(),
  isActive: z.boolean().optional(),
});

// Answers use stable question IDs. Optional questions may be omitted, but an
// answer that is supplied must still match the question's declared type.
function validateAnswers(questions, answers) {
  if (!answers || typeof answers !== 'object' || Array.isArray(answers)) {
    return ['Answers must be an object keyed by question ID'];
  }
  const errors = [];
  const ids = new Set(questions.map(question => question.id));
  for (const id of Object.keys(answers)) {
    if (!ids.has(id)) errors.push(`Unknown question: ${id}`);
  }
  for (const question of questions) {
    const value = answers[question.id];
    const empty = value == null || (typeof value === 'string' && !value.trim()) ||
      (Array.isArray(value) && value.length === 0);
    if (empty) {
      if (question.required !== false) errors.push(`Answer required: ${question.id}`);
      continue;
    }
    let valid = false;
    switch (question.type) {
      case 'text': valid = typeof value === 'string'; break;
      case 'single_choice': valid = question.options?.includes(value) === true; break;
      case 'multiple_choice':
        valid = Array.isArray(value) && new Set(value).size === value.length &&
          value.every(option => question.options?.includes(option));
        break;
      case 'yes_no': valid = typeof value === 'boolean'; break;
      case 'rating': valid = Number.isInteger(value) && value >= 1 && value <= 5; break;
      case 'photo_upload': valid = z.array(z.string().url()).min(1).max(5).safeParse(value).success; break;
    }
    if (!valid) errors.push(`Invalid answer for ${question.type}: ${question.id}`);
  }
  return errors;
}

module.exports = { createQuestionFlowSchema, updateQuestionFlowSchema, validateAnswers };
