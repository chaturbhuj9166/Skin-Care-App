const express = require('express');
const { z } = require('zod');
const validate = require('../middleware/validate');
const { authenticate, requireUser } = require('../middleware/auth');
const userController = require('../controllers/user.controller');

const router = express.Router();

router.use(authenticate, requireUser);

const CASE_STATUSES = ['PENDING', 'ASSIGNED', 'IN_REVIEW', 'SOLVED', 'CLOSED'];

const updateProfileSchema = z.object({
  name: z.string().min(1).optional(),
  email: z.string().email().optional(),
  gender: z.string().optional(),
  age: z.number().int().positive().optional(),
  avatar: z.string().optional(),
});

// FCM device token registration (push notifications).
const deviceTokenSchema = z.object({
  token: z.string().min(10),
});

const listCasesQuerySchema = z.object({
  status: z.enum(CASE_STATUSES).optional(),
  page: z.string().optional(),
  limit: z.string().optional(),
});

const createCaseSchema = z.object({
  questionFlowId: z.string().min(1),
  answers: z.any(),
  photos: z.array(z.string().url()).max(5).optional(),
});

const messageSchema = z
  .object({
    text: z.string().optional(),
    fileUrl: z.string().optional(),
  })
  .refine((data) => data.text || data.fileUrl, { message: 'Either text or fileUrl is required' });

const notificationsQuerySchema = z.object({
  unread: z.string().optional(),
});

const createTicketSchema = z.object({
  subject: z.string().min(1),
  description: z.string().min(1),
  priority: z.enum(['LOW', 'MEDIUM', 'HIGH']),
});

const submitRatingSchema = z.object({
  score: z.number().int().min(1).max(5),
  comment: z.string().max(1000).optional(),
});

router.get('/profile', userController.getProfile);
router.put('/profile', validate({ body: updateProfileSchema }), userController.updateProfile);
router.post('/device-token', validate({ body: deviceTokenSchema }), userController.registerDeviceToken);
router.delete('/device-token', validate({ body: deviceTokenSchema }), userController.deleteDeviceToken);
router.get('/question-flow', userController.getActiveQuestionFlow);
router.get('/doctors', userController.listDoctors);

router.get('/cases', validate({ query: listCasesQuerySchema }), userController.listCases);
router.post('/cases', validate({ body: createCaseSchema }), userController.createCase);
router.get('/cases/:id', userController.getCaseById);
router.post('/cases/:id/rating', validate({ body: submitRatingSchema }), userController.submitRating);
router.get('/cases/:id/messages', userController.listCaseMessages);
router.post('/cases/:id/messages', validate({ body: messageSchema }), userController.postCaseMessage);

router.get('/notifications', validate({ query: notificationsQuerySchema }), userController.listNotifications);
router.patch('/notifications/:id/read', userController.markNotificationRead);

router.post('/tickets', validate({ body: createTicketSchema }), userController.createTicket);
router.get('/tickets', userController.listTickets);

router.get('/appointments', userController.listAppointments);

module.exports = router;
