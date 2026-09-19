const { v4: uuidv4 } = require('uuid');
const prisma = require('../config/db');
const asyncHandler = require('../utils/asyncHandler');
const ApiError = require('../utils/ApiError');
const { getPagination, buildPaginatedResponse } = require('../utils/pagination');

const socket = require('../services/socket');
const fcm = require('../services/fcm');
const agora = require('../services/agora');
const { recordCaseStatus } = require('../services/caseHistory');

async function getAssignedCaseOrThrow(caseId, doctorId) {
  const found = await prisma.case.findUnique({ where: { id: caseId } });
  if (!found || found.doctorId !== doctorId) throw ApiError.notFound('Case not found');
  return found;
}

// GET /api/doctors/profile
const getProfile = asyncHandler(async (req, res) => {
  const ratingAgg = await prisma.rating.aggregate({
    where: { doctorId: req.doctor.id },
    _avg: { score: true },
    _count: { _all: true },
  });
  res.json({ doctor: { ...req.doctor, rating: ratingAgg._avg.score, reviewCount: ratingAgg._count._all } });
});

// PUT /api/doctors/profile
const updateProfile = asyncHandler(async (req, res) => {
  const { name, specialization, experience, avatar } = req.body;

  const doctor = await prisma.doctor.update({
    where: { id: req.doctor.id },
    data: {
      ...(name !== undefined && { name }),
      ...(specialization !== undefined && { specialization }),
      ...(experience !== undefined && { experience }),
      ...(avatar !== undefined && { avatar }),
    },
  });

  const { password, ...safeDoctor } = doctor;
  res.json({ doctor: safeDoctor });
});

// PUT /api/doctors/availability
const updateAvailability = asyncHandler(async (req, res) => {
  const { isAvailable } = req.body;

  const doctor = await prisma.doctor.update({
    where: { id: req.doctor.id },
    data: { isAvailable },
  });

  const { password, ...safeDoctor } = doctor;
  res.json({ doctor: safeDoctor });
});

// GET /api/doctors/cases?status=&page=
const listCases = asyncHandler(async (req, res) => {
  const { status, page: pageQuery, limit: limitQuery } = req.query;
  const { page, limit, skip, take } = getPagination({ page: pageQuery, limit: limitQuery });

  const where = { doctorId: req.doctor.id, ...(status && { status }) };

  const [data, total] = await Promise.all([
    prisma.case.findMany({
      where,
      skip,
      take,
      orderBy: { createdAt: 'desc' },
      include: { user: { select: { id: true, name: true, avatar: true, gender: true, age: true } } },
    }),
    prisma.case.count({ where }),
  ]);

  res.json(buildPaginatedResponse(data, total, page, limit));
});

// GET /api/doctors/cases/:id
const getCaseById = asyncHandler(async (req, res) => {
  const found = await prisma.case.findUnique({
    where: { id: req.params.id },
    include: {
      user: { select: { id: true, name: true, avatar: true, gender: true, age: true, phone: true, email: true } },
      questionFlow: true,
      solution: true,
      videoCalls: true,
      rating: true,
    },
  });

  if (!found || found.doctorId !== req.doctor.id) throw ApiError.notFound('Case not found');
  res.json({ case: found });
});

// POST /api/doctors/cases/:id/solution
const addSolution = asyncHandler(async (req, res) => {
  const caseRecord = await getAssignedCaseOrThrow(req.params.id, req.doctor.id);
  const { text, prescription, followUpDate } = req.body;

  const [solution] = await prisma.$transaction([
    prisma.solution.create({
      data: {
        caseId: caseRecord.id,
        doctorId: req.doctor.id,
        text,
        prescription,
        followUpDate: followUpDate ? new Date(followUpDate) : null,
      },
    }),
    prisma.case.update({ where: { id: caseRecord.id }, data: { status: 'SOLVED' } }),
    prisma.notification.create({
      data: {
        userId: caseRecord.userId,
        userType: 'USER',
        title: 'Your case has a solution',
        body: `Dr. ${req.doctor.name} has reviewed your case and added a solution.`,
        type: 'SOLUTION_ADDED',
        caseId: caseRecord.id,
      },
    }),
  ]);

  await recordCaseStatus({
    caseId: caseRecord.id,
    status: 'SOLVED',
    changedByType: 'DOCTOR',
    changedById: req.doctor.id,
  });

  await fcm.sendPushNotification({
    title: 'Your case has a solution',
    body: `Dr. ${req.doctor.name} has reviewed your case and added a solution.`,
    data: { caseId: caseRecord.id, type: 'SOLUTION_ADDED' },
  });

  socket.emitToCase(caseRecord.id, 'solution_added', { caseId: caseRecord.id, solution });
  socket.emitToUser(caseRecord.userId, 'solution_added', { caseId: caseRecord.id, solution });
  socket.emitToUser(caseRecord.userId, 'notification', {
    title: 'Your case has a solution',
    body: `Dr. ${req.doctor.name} has reviewed your case and added a solution.`,
    type: 'SOLUTION_ADDED',
  });

  res.status(201).json({ solution });
});

// GET /api/doctors/cases/:id/messages
const listCaseMessages = asyncHandler(async (req, res) => {
  const caseRecord = await getAssignedCaseOrThrow(req.params.id, req.doctor.id);

  const messages = await prisma.message.findMany({
    where: { caseId: req.params.id },
    orderBy: { createdAt: 'asc' },
  });

  // Opening the thread marks the patient's messages as read/seen by this doctor.
  const { count } = await prisma.message.updateMany({
    where: { caseId: caseRecord.id, senderType: 'USER', isRead: false },
    data: { isRead: true },
  });
  if (count > 0) socket.emitToCase(caseRecord.id, 'messages_read', { caseId: caseRecord.id, readBy: 'DOCTOR' });

  res.json({ data: messages });
});

// POST /api/doctors/cases/:id/messages
const postCaseMessage = asyncHandler(async (req, res) => {
  const caseRecord = await getAssignedCaseOrThrow(req.params.id, req.doctor.id);
  const { text, fileUrl } = req.body;

  const message = await prisma.message.create({
    data: {
      caseId: caseRecord.id,
      senderId: req.doctor.id,
      senderType: 'DOCTOR',
      text: text || null,
      fileUrl: fileUrl || null,
    },
  });

  socket.emitToCase(caseRecord.id, 'new_message', message);

  await prisma.notification.create({
    data: {
      userId: caseRecord.userId,
      userType: 'USER',
      title: 'New message from your doctor',
      body: `Dr. ${req.doctor.name} sent you a message.`,
      type: 'NEW_MESSAGE',
      caseId: caseRecord.id,
    },
  });
  socket.emitToUser(caseRecord.userId, 'notification', {
    title: 'New message from your doctor',
    body: `Dr. ${req.doctor.name} sent you a message.`,
    type: 'NEW_MESSAGE',
    caseId: caseRecord.id,
  });

  res.status(201).json({ message });
});

// POST /api/doctors/cases/:id/schedule-call
const scheduleCall = asyncHandler(async (req, res) => {
  const caseRecord = await getAssignedCaseOrThrow(req.params.id, req.doctor.id);
  const { scheduledAt } = req.body;

  // Rescheduling replaces the case's pending call rather than stacking a
  // second one, so every screen reading "the" scheduled time for this case
  // agrees on a single value.
  await prisma.videoCall.updateMany({
    where: { caseId: caseRecord.id, status: 'SCHEDULED' },
    data: { status: 'CANCELLED' },
  });

  const roomId = uuidv4();

  const videoCall = await prisma.videoCall.create({
    data: {
      caseId: caseRecord.id,
      scheduledAt: new Date(scheduledAt),
      roomId,
      status: 'SCHEDULED',
    },
  });

  const agoraToken = agora.generateRtcToken(roomId);

  await prisma.notification.create({
    data: {
      userId: caseRecord.userId,
      userType: 'USER',
      title: 'Video call scheduled',
      body: `Dr. ${req.doctor.name} scheduled a video consultation with you.`,
      caseId: caseRecord.id,
      type: 'CALL_SCHEDULED',
    },
  });

  await fcm.sendPushNotification({
    title: 'Video call scheduled',
    body: `Dr. ${req.doctor.name} scheduled a video consultation with you.`,
    data: { caseId: caseRecord.id, roomId, type: 'CALL_SCHEDULED' },
  });

  const payload = { caseId: caseRecord.id, roomId, scheduledAt: videoCall.scheduledAt };
  socket.emitToCase(caseRecord.id, 'call_scheduled', payload);
  socket.emitToUser(caseRecord.userId, 'call_scheduled', payload);
  socket.emitToAllAdmins('call_scheduled', payload);

  res.status(201).json({ videoCall, agoraToken });
});

// GET /api/doctors/appointments
const listAppointments = asyncHandler(async (req, res) => {
  const appointments = await prisma.videoCall.findMany({
    where: { case: { doctorId: req.doctor.id }, status: { not: 'CANCELLED' } },
    orderBy: { scheduledAt: 'desc' },
    include: {
      case: { select: { id: true, status: true, user: { select: { id: true, name: true, avatar: true } } } },
    },
  });

  res.json({ data: appointments });
});

// GET /api/doctors/analytics
const getAnalytics = asyncHandler(async (req, res) => {
  const doctorId = req.doctor.id;

  const [totalCases, solvedCases, pendingCases, ratingAgg] = await Promise.all([
    prisma.case.count({ where: { doctorId } }),
    prisma.case.count({ where: { doctorId, status: { in: ['SOLVED', 'CLOSED'] } } }),
    prisma.case.count({ where: { doctorId, status: { in: ['ASSIGNED', 'IN_REVIEW'] } } }),
    prisma.rating.aggregate({ where: { doctorId }, _avg: { score: true }, _count: { _all: true } }),
  ]);

  res.json({
    totalCases,
    solvedCases,
    pendingCases,
    avgRating: ratingAgg._avg.score,
    reviewCount: ratingAgg._count._all,
  });
});

module.exports = {
  getProfile,
  updateProfile,
  updateAvailability,
  listCases,
  getCaseById,
  addSolution,
  listCaseMessages,
  postCaseMessage,
  scheduleCall,
  listAppointments,
  getAnalytics,
};
