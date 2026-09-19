const express = require('express');
const { z } = require('zod');
const validate = require('../middleware/validate');
const { authenticate, requireDoctor } = require('../middleware/auth');
const doctorController = require('../controllers/doctor.controller');

const router = express.Router();

router.use(authenticate, requireDoctor);

const CASE_STATUSES = ['PENDING', 'ASSIGNED', 'IN_REVIEW', 'SOLVED', 'CLOSED'];

const updateProfileSchema = z.object({
  name: z.string().min(1).optional(),
  specialization: z.string().optional(),
  experience: z.number().int().min(0).optional(),
  avatar: z.string().optional(),
});

const updateAvailabilitySchema = z.object({
  isAvailable: z.boolean(),
});

const listCasesQuerySchema = z.object({
  status: z.enum(CASE_STATUSES).optional(),
  page: z.string().optional(),
  limit: z.string().optional(),
});

const addSolutionSchema = z.object({
  text: z.string().min(1),
  prescription: z.any(),
  followUpDate: z.string().datetime().optional().or(z.string().optional()),
});

const messageSchema = z
  .object({
    text: z.string().optional(),
    fileUrl: z.string().optional(),
  })
  .refine((data) => data.text || data.fileUrl, { message: 'Either text or fileUrl is required' });

const scheduleCallSchema = z.object({
  scheduledAt: z.string().min(1),
});

router.get('/profile', doctorController.getProfile);
router.put('/profile', validate({ body: updateProfileSchema }), doctorController.updateProfile);
router.put('/availability', validate({ body: updateAvailabilitySchema }), doctorController.updateAvailability);

router.get('/cases', validate({ query: listCasesQuerySchema }), doctorController.listCases);
router.get('/cases/:id', doctorController.getCaseById);
router.post('/cases/:id/solution', validate({ body: addSolutionSchema }), doctorController.addSolution);
router.get('/cases/:id/messages', doctorController.listCaseMessages);
router.post('/cases/:id/messages', validate({ body: messageSchema }), doctorController.postCaseMessage);
router.post('/cases/:id/schedule-call', validate({ body: scheduleCallSchema }), doctorController.scheduleCall);

router.get('/appointments', doctorController.listAppointments);
router.get('/analytics', doctorController.getAnalytics);

module.exports = router;
