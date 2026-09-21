const express = require('express');
const { z } = require('zod');
const validate = require('../middleware/validate');
const { authenticate, requireAdmin } = require('../middleware/auth');
const adminController = require('../controllers/admin.controller');
const { createQuestionFlowSchema, updateQuestionFlowSchema } = require('../validation/questionFlow');

const router = express.Router();

router.use(authenticate, requireAdmin);

const CASE_STATUSES = ['PENDING', 'ASSIGNED', 'IN_REVIEW', 'SOLVED', 'CLOSED'];
const TICKET_STATUSES = ['OPEN', 'IN_PROGRESS', 'CLOSED'];
const TICKET_PRIORITIES = ['LOW', 'MEDIUM', 'HIGH'];
const VIDEO_CALL_STATUSES = ['SCHEDULED', 'ONGOING', 'COMPLETED', 'CANCELLED'];
const NOTIFICATION_TARGETS = ['ALL_USERS', 'ALL_DOCTORS', 'SPECIFIC_USER', 'SPECIFIC_DOCTOR'];

const dateString = z.string().refine((v) => !Number.isNaN(Date.parse(v)), 'Must be a valid date');

const analyticsQuerySchema = z.object({
  from: dateString.optional(),
  to: dateString.optional(),
});

const updateAdminProfileSchema = z.object({
  name: z.string().min(1).optional(),
  email: z.string().email().optional(),
});

const changeAdminPasswordSchema = z.object({
  oldPassword: z.string().min(1),
  newPassword: z.string().min(6),
});

const listCasesQuerySchema = z.object({
  status: z.enum(CASE_STATUSES).optional(),
  doctorId: z.string().optional(),
  search: z.string().optional(),
  from: dateString.optional(),
  to: dateString.optional(),
  page: z.string().optional(),
  limit: z.string().optional(),
});

const exportCasesQuerySchema = listCasesQuerySchema.omit({ page: true, limit: true });

const assignCaseSchema = z.object({
  doctorId: z.string().min(1),
});

const updateCaseStatusSchema = z.object({
  status: z.enum(CASE_STATUSES),
});

const paginationQuerySchema = z.object({
  search: z.string().optional(),
  page: z.string().optional(),
  limit: z.string().optional(),
});

const createDoctorSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
  phone: z.string().min(6),
  specialization: z.string().optional(),
  experience: z.number().int().min(0).optional(),
});

const updateDoctorSchema = z.object({
  name: z.string().min(1).optional(),
  email: z.string().email().optional(),
  phone: z.string().min(6).optional(),
  specialization: z.string().optional(),
  experience: z.number().int().min(0).optional(),
  isAvailable: z.boolean().optional(),
  avatar: z.string().optional(),
});

const updateUserSchema = z.object({
  isBlocked: z.boolean(),
});

const listTicketsQuerySchema = z.object({
  status: z.enum(TICKET_STATUSES).optional(),
  priority: z.enum(TICKET_PRIORITIES).optional(),
});

const updateTicketSchema = z.object({
  status: z.enum(TICKET_STATUSES).optional(),
  reply: z.string().optional(),
});

const sendNotificationSchema = z.object({
  title: z.string().min(1),
  body: z.string().min(1),
  target: z.enum(NOTIFICATION_TARGETS),
  targetId: z.string().optional(),
});

const videoCallsQuerySchema = z.object({
  status: z.enum(VIDEO_CALL_STATUSES).optional(),
});

const reportsQuerySchema = z.object({
  type: z.enum(['cases', 'users', 'doctors', 'tickets']).optional(),
  from: dateString.optional(),
  to: dateString.optional(),
});

// Profile / settings
router.get('/profile', adminController.getProfile);
router.put('/profile', validate({ body: updateAdminProfileSchema }), adminController.updateProfile);
router.put('/profile/password', validate({ body: changeAdminPasswordSchema }), adminController.changePassword);

// Analytics
router.get('/analytics', validate({ query: analyticsQuerySchema }), adminController.getAnalytics);

// Cases
router.get('/cases', validate({ query: listCasesQuerySchema }), adminController.listCases);
router.get('/cases/export', validate({ query: exportCasesQuerySchema }), adminController.exportCases);
router.get('/cases/:id', adminController.getCaseById);
router.patch('/cases/:id/assign', validate({ body: assignCaseSchema }), adminController.assignCase);
router.patch('/cases/:id/status', validate({ body: updateCaseStatusSchema }), adminController.updateCaseStatus);

// Doctors
router.get('/doctors', validate({ query: paginationQuerySchema }), adminController.listDoctors);
router.get('/doctors/:id', adminController.getDoctorById);
router.post('/doctors', validate({ body: createDoctorSchema }), adminController.createDoctor);
router.put('/doctors/:id', validate({ body: updateDoctorSchema }), adminController.updateDoctor);
router.delete('/doctors/:id', adminController.deleteDoctor);

// Users
router.get('/users', validate({ query: paginationQuerySchema }), adminController.listUsers);
router.get('/users/:id', adminController.getUserById);
router.put('/users/:id', validate({ body: updateUserSchema }), adminController.updateUser);

// Tickets
router.get('/tickets', validate({ query: listTicketsQuerySchema }), adminController.listTickets);
router.patch('/tickets/:id', validate({ body: updateTicketSchema }), adminController.updateTicket);

// Question flows
router.get('/question-flows', adminController.listQuestionFlows);
router.post('/question-flows', validate({ body: createQuestionFlowSchema }), adminController.createQuestionFlow);
router.put('/question-flows/:id', validate({ body: updateQuestionFlowSchema }), adminController.updateQuestionFlow);
router.delete('/question-flows/:id', adminController.deleteQuestionFlow);

// Notifications
router.post('/notifications/send', validate({ body: sendNotificationSchema }), adminController.sendNotification);
router.get('/notifications', validate({ query: paginationQuerySchema.omit({ search: true }) }), adminController.listNotifications);

// Video calls
router.get('/video-calls', validate({ query: videoCallsQuerySchema }), adminController.listVideoCalls);

// Reports
router.get('/reports', validate({ query: reportsQuerySchema }), adminController.getReports);

module.exports = router;
