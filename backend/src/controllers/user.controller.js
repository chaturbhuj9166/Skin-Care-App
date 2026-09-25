const prisma = require('../config/db');
const asyncHandler = require('../utils/asyncHandler');
const ApiError = require('../utils/ApiError');
const { getPagination, buildPaginatedResponse } = require('../utils/pagination');
const socket = require('../services/socket');
const { validateAnswers } = require('../validation/questionFlow');
const { recordCaseStatus } = require('../services/caseHistory');
const agora = require('../services/agora');
const env = require('../config/env');
const fcm = require('../services/fcm');

async function getOwnCaseOrThrow(caseId, userId) {
  const found = await prisma.case.findUnique({ where: { id: caseId } });
  if (!found || found.userId !== userId) throw ApiError.notFound('Case not found');
  return found;
}

// User access to the published questionnaire does not expose admin draft flows.
const getActiveQuestionFlow = asyncHandler(async (req, res) => {
  const questionFlow = await prisma.questionFlow.findFirst({
    where: { isActive: true },
    orderBy: { createdAt: 'desc' },
  });
  if (!questionFlow) throw ApiError.notFound('No active question flow is available');
  res.json({ questionFlow });
});

// GET /api/users/profile
const getProfile = asyncHandler(async (req, res) => {
  res.json({ user: req.user });
});

// GET /api/users/doctors
// Browse-only listing so users can see available doctors; case assignment
// itself stays admin-driven (see docs/client-spec-checklist.md contract decisions).
const listDoctors = asyncHandler(async (req, res) => {
  const doctors = await prisma.doctor.findMany({
    orderBy: { name: 'asc' },
    select: {
      id: true,
      name: true,
      specialization: true,
      experience: true,
      avatar: true,
      isAvailable: true,
    },
  });

  const ratingStats = doctors.length
    ? await prisma.rating.groupBy({
        by: ['doctorId'],
        where: { doctorId: { in: doctors.map((d) => d.id) } },
        _avg: { score: true },
        _count: { _all: true },
      })
    : [];
  const statsByDoctor = ratingStats.reduce((acc, row) => {
    acc[row.doctorId] = { rating: row._avg.score, reviewCount: row._count._all };
    return acc;
  }, {});

  const shaped = doctors.map((doctor) => ({
    ...doctor,
    rating: statsByDoctor[doctor.id]?.rating ?? null,
    reviewCount: statsByDoctor[doctor.id]?.reviewCount ?? 0,
  }));

  res.json({ data: shaped });
});

// PUT /api/users/profile
const updateProfile = asyncHandler(async (req, res) => {
  const { name, email, gender, age, avatar } = req.body;

  const user = await prisma.user.update({
    where: { id: req.user.id },
    data: {
      ...(name !== undefined && { name }),
      ...(email !== undefined && { email }),
      ...(gender !== undefined && { gender }),
      ...(age !== undefined && { age }),
      ...(avatar !== undefined && { avatar }),
    },
  });

  res.json({ user });
});

// GET /api/users/cases?status=&page=
const listCases = asyncHandler(async (req, res) => {
  const { status, page: pageQuery, limit: limitQuery } = req.query;
  const { page, limit, skip, take } = getPagination({ page: pageQuery, limit: limitQuery });

  const where = { userId: req.user.id, ...(status && { status }) };

  const [data, total] = await Promise.all([
    prisma.case.findMany({
      where,
      skip,
      take,
      orderBy: { createdAt: 'desc' },
      include: {
        doctor: { select: { id: true, name: true, specialization: true, avatar: true, experience: true, isAvailable: true } },
        questionFlow: { select: { questions: true } },
        solution: true,
        rating: true,
        videoCalls: true,
      },
    }),
    prisma.case.count({ where }),
  ]);

  res.json(buildPaginatedResponse(data, total, page, limit));
});

// POST /api/users/cases
const createCase = asyncHandler(async (req, res) => {
  const { questionFlowId, answers, photos, videos } = req.body;

  // The doctor needs the patient's age and gender to review a case.
  if (!req.user.age || !req.user.gender) {
    throw ApiError.badRequest('Please add your age and gender before submitting a case');
  }

  const flow = await prisma.questionFlow.findUnique({ where: { id: questionFlowId } });
  if (!flow) throw ApiError.badRequest('Invalid questionFlowId');
  if (!flow.isActive) throw ApiError.badRequest('This question flow is no longer active. Please load the current questionnaire.');
  const answerErrors = validateAnswers(flow.questions, answers);
  if (answerErrors.length) throw ApiError.badRequest('Please check your questionnaire answers', answerErrors);
  const uploadedPhotos = [...new Set([
    ...(photos || []),
    ...flow.questions.filter(question => question.type === 'photo_upload')
      .flatMap(question => answers[question.id] || []),
  ])];
  if (uploadedPhotos.length > 5) throw ApiError.badRequest('A case can include at most five photos');
  const uploadedVideos = [...new Set(videos || [])];
  if (uploadedVideos.length > 2) throw ApiError.badRequest('A case can include at most two videos');

  const newCase = await prisma.case.create({
    data: {
      userId: req.user.id,
      questionFlowId,
      answers,
      photos: uploadedPhotos,
      videos: uploadedVideos,
    },
  });

  await recordCaseStatus({
    caseId: newCase.id,
    status: newCase.status,
    changedByType: 'USER',
    changedById: req.user.id,
  });

  // Notify every admin (in-app notification row + live socket push).
  const admins = await prisma.admin.findMany({ select: { id: true } });
  if (admins.length) {
    await prisma.notification.createMany({
      data: admins.map((admin) => ({
        userId: admin.id,
        userType: 'ADMIN',
        title: 'New case submitted',
        body: `${req.user.name} submitted a new consultation case.`,
        type: 'NEW_CASE',
        caseId: newCase.id,
      })),
    });
  }

  socket.emitToAllAdmins('notification', {
    title: 'New case submitted',
    body: `${req.user.name} submitted a new consultation case.`,
    type: 'NEW_CASE',
    caseId: newCase.id,
  });

  res.status(201).json({ case: newCase });
});

// GET /api/users/cases/:id
const getCaseById = asyncHandler(async (req, res) => {
  const found = await prisma.case.findUnique({
    where: { id: req.params.id },
    include: {
      doctor: { select: { id: true, name: true, specialization: true, avatar: true, experience: true, isAvailable: true } },
      questionFlow: true,
      solution: true,
      videoCalls: true,
      rating: true,
    },
  });

  if (!found || found.userId !== req.user.id) throw ApiError.notFound('Case not found');
  res.json({ case: found });
});

// POST /api/users/cases/:id/rating
// A user may rate a case once it has a solution, and only once per case.
const submitRating = asyncHandler(async (req, res) => {
  const caseRecord = await getOwnCaseOrThrow(req.params.id, req.user.id);
  const { score, comment } = req.body;

  if (!caseRecord.doctorId) throw ApiError.badRequest('This case has no assigned doctor to rate');
  if (!['SOLVED', 'CLOSED'].includes(caseRecord.status)) {
    throw ApiError.badRequest('You can rate a doctor once your case has a solution');
  }

  const existing = await prisma.rating.findUnique({ where: { caseId: caseRecord.id } });
  if (existing) throw ApiError.conflict('You have already rated this case');

  const rating = await prisma.rating.create({
    data: {
      caseId: caseRecord.id,
      userId: req.user.id,
      doctorId: caseRecord.doctorId,
      score,
      comment: comment || null,
    },
  });

  res.status(201).json({ rating });
});

// GET /api/users/cases/:id/messages
const listCaseMessages = asyncHandler(async (req, res) => {
  const caseRecord = await getOwnCaseOrThrow(req.params.id, req.user.id);

  const messages = await prisma.message.findMany({
    where: { caseId: req.params.id },
    orderBy: { createdAt: 'asc' },
  });

  // Opening the thread marks the doctor's messages as read/seen by this user.
  const { count } = await prisma.message.updateMany({
    where: { caseId: caseRecord.id, senderType: 'DOCTOR', isRead: false },
    data: { isRead: true },
  });
  if (count > 0) socket.emitToCase(caseRecord.id, 'messages_read', { caseId: caseRecord.id, readBy: 'USER' });

  res.json({ data: messages });
});

// POST /api/users/cases/:id/messages
const postCaseMessage = asyncHandler(async (req, res) => {
  const caseRecord = await getOwnCaseOrThrow(req.params.id, req.user.id);
  const { text, fileUrl } = req.body;

  const message = await prisma.message.create({
    data: {
      caseId: caseRecord.id,
      senderId: req.user.id,
      senderType: 'USER',
      text: text || null,
      fileUrl: fileUrl || null,
    },
  });

  socket.emitToCase(caseRecord.id, 'new_message', message);

  if (caseRecord.doctorId) {
    await prisma.notification.create({
      data: {
        userId: caseRecord.doctorId,
        userType: 'DOCTOR',
        title: 'New message',
        body: `${req.user.name} sent a new message on their case.`,
        type: 'NEW_MESSAGE',
        caseId: caseRecord.id,
      },
    });
    socket.emitToDoctor(caseRecord.doctorId, 'notification', {
      title: 'New message',
      body: `${req.user.name} sent a new message on their case.`,
      type: 'NEW_MESSAGE',
      caseId: caseRecord.id,
    });
    await fcm.sendPushNotification({
      ownerId: caseRecord.doctorId,
      ownerType: 'DOCTOR',
      title: 'New message',
      body: `${req.user.name} sent a new message on their case.`,
      data: { caseId: caseRecord.id, type: 'NEW_MESSAGE' },
    });
  }

  res.status(201).json({ message });
});

// GET /api/users/cases/:id/video-token
// Generates a fresh Agora token on demand, right when the patient is about to
// join the call, rather than relying on the one-hour token the doctor was
// handed at schedule time (see scheduleCall in doctor.controller.js).
const getVideoToken = asyncHandler(async (req, res) => {
  const caseRecord = await getOwnCaseOrThrow(req.params.id, req.user.id);

  const videoCall = await prisma.videoCall.findFirst({
    where: { caseId: caseRecord.id, status: { in: ['SCHEDULED', 'ONGOING'] } },
    orderBy: { scheduledAt: 'desc' },
  });
  if (!videoCall) throw ApiError.badRequest('No video call is scheduled for this case');

  // First participant to fetch a token for a still-SCHEDULED call flips it to
  // ONGOING so other screens (doctor appointment list, admin) reflect reality.
  if (videoCall.status === 'SCHEDULED') {
    await prisma.videoCall.update({ where: { id: videoCall.id }, data: { status: 'ONGOING' } });
  }

  const token = agora.generateRtcToken(videoCall.roomId);

  res.json({ appId: env.AGORA_APP_ID, channel: videoCall.roomId, token, uid: 0 });
});

// GET /api/users/notifications?unread=true
const listNotifications = asyncHandler(async (req, res) => {
  const { unread } = req.query;
  const where = { userId: req.user.id, userType: 'USER', ...(unread === 'true' && { isRead: false }) };

  const notifications = await prisma.notification.findMany({ where, orderBy: { createdAt: 'desc' } });
  res.json({ data: notifications });
});

// PATCH /api/users/notifications/:id/read
const markNotificationRead = asyncHandler(async (req, res) => {
  const notification = await prisma.notification.findUnique({ where: { id: req.params.id } });
  if (!notification || notification.userId !== req.user.id || notification.userType !== 'USER') {
    throw ApiError.notFound('Notification not found');
  }

  const updated = await prisma.notification.update({ where: { id: notification.id }, data: { isRead: true } });
  res.json({ notification: updated });
});

// POST /api/users/tickets
const createTicket = asyncHandler(async (req, res) => {
  const { subject, description, priority } = req.body;

  const ticket = await prisma.ticket.create({
    data: { userId: req.user.id, subject, description, priority },
  });

  // Notify every admin (in-app notification row + live socket push), the same
  // way a newly submitted case does.
  const admins = await prisma.admin.findMany({ select: { id: true } });
  const notice = {
    title: 'New support ticket',
    body: `${req.user.name} raised a support ticket: ${ticket.subject}`,
    type: 'NEW_TICKET',
  };
  if (admins.length) {
    await prisma.notification.createMany({
      data: admins.map((admin) => ({ ...notice, userId: admin.id, userType: 'ADMIN' })),
    });
  }

  socket.emitToAllAdmins('notification', { ...notice, ticketId: ticket.id });

  res.status(201).json({ ticket });
});

// GET /api/users/tickets
const listTickets = asyncHandler(async (req, res) => {
  const tickets = await prisma.ticket.findMany({
    where: { userId: req.user.id },
    orderBy: { createdAt: 'desc' },
  });
  res.json({ data: tickets });
});

// GET /api/users/appointments
const listAppointments = asyncHandler(async (req, res) => {
  const cases = await prisma.case.findMany({ where: { userId: req.user.id }, select: { id: true } });
  const caseIds = cases.map((c) => c.id);

  const appointments = caseIds.length
    ? await prisma.videoCall.findMany({
        where: { caseId: { in: caseIds }, status: { not: 'CANCELLED' } },
        orderBy: { scheduledAt: 'desc' },
        include: {
          case: {
            select: {
              id: true,
              status: true,
              doctor: { select: { id: true, name: true, specialization: true, avatar: true, experience: true, isAvailable: true } },
            },
          },
        },
      })
    : [];

  res.json({ data: appointments });
});


// POST /api/users/device-token
// Registers this install's FCM token so services/fcm.js can push to it.
// Idempotent: re-registering a token that already exists just re-points it
// at the current owner (a device handed over to another account).
const registerDeviceToken = asyncHandler(async (req, res) => {
  const { token } = req.body;

  const deviceToken = await prisma.deviceToken.upsert({
    where: { token },
    update: { ownerId: req.user.id, ownerType: 'USER' },
    create: { token, ownerId: req.user.id, ownerType: 'USER' },
  });

  res.status(201).json({ deviceToken });
});

// DELETE /api/users/device-token
// Called on logout / when push is turned off. Only ever removes a token that
// belongs to the caller, and succeeds even when it was already gone.
const deleteDeviceToken = asyncHandler(async (req, res) => {
  const { token } = req.body;

  const { count } = await prisma.deviceToken.deleteMany({
    where: { token, ownerId: req.user.id, ownerType: 'USER' },
  });

  res.json({ success: true, removed: count });
});

module.exports = {
  registerDeviceToken,
  deleteDeviceToken,
  getActiveQuestionFlow,
  getProfile,
  listDoctors,
  updateProfile,
  listCases,
  createCase,
  getCaseById,
  submitRating,
  getVideoToken,
  listCaseMessages,
  postCaseMessage,
  listNotifications,
  markNotificationRead,
  createTicket,
  listTickets,
  listAppointments,
};
