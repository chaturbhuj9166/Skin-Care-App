const bcrypt = require('bcryptjs');
const prisma = require('../config/db');
const asyncHandler = require('../utils/asyncHandler');
const ApiError = require('../utils/ApiError');
const sanitize = require('../utils/sanitize');
const { getPagination, buildPaginatedResponse } = require('../utils/pagination');
const socket = require('../services/socket');
const fcm = require('../services/fcm');
const { recordCaseStatus } = require('../services/caseHistory');
const { toCsv } = require('../utils/csv');
const { buildCaseFilter } = require('../utils/caseFilter');

const SALT_ROUNDS = 10;

// ---------------------------------------------------------------------------
// Profile / settings
// ---------------------------------------------------------------------------

// GET /api/admin/profile
const getProfile = asyncHandler(async (req, res) => {
  res.json({ admin: req.admin });
});

// PUT /api/admin/profile
const updateProfile = asyncHandler(async (req, res) => {
  const { name, email } = req.body;

  if (email) {
    const existing = await prisma.admin.findUnique({ where: { email } });
    if (existing && existing.id !== req.admin.id) throw ApiError.conflict('This email is already in use');
  }

  const admin = await prisma.admin.update({
    where: { id: req.admin.id },
    data: {
      ...(name !== undefined && { name }),
      ...(email !== undefined && { email }),
    },
  });

  res.json({ admin: sanitize(admin) });
});

// PUT /api/admin/profile/password
const changePassword = asyncHandler(async (req, res) => {
  const { oldPassword, newPassword } = req.body;

  const existing = await prisma.admin.findUnique({ where: { id: req.admin.id } });
  const valid = await bcrypt.compare(oldPassword, existing.password);
  if (!valid) throw ApiError.badRequest('Current password is incorrect');

  const hashed = await bcrypt.hash(newPassword, SALT_ROUNDS);
  await prisma.admin.update({ where: { id: existing.id }, data: { password: hashed } });

  res.json({ success: true });
});

// ---------------------------------------------------------------------------
// Analytics
// ---------------------------------------------------------------------------

// GET /api/admin/analytics?from=&to=
const getAnalytics = asyncHandler(async (req, res) => {
  const { from, to } = req.query;
  const dateFilter = {};
  if (from) dateFilter.gte = new Date(from);
  if (to) dateFilter.lte = new Date(to);
  const hasDateFilter = Boolean(from || to);

  const sixMonthsAgo = new Date();
  sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 5);
  sixMonthsAgo.setDate(1);
  sixMonthsAgo.setHours(0, 0, 0, 0);

  const eightWeeksAgo = new Date();
  eightWeeksAgo.setDate(eightWeeksAgo.getDate() - 7 * 7);

  const [
    totalUsers,
    totalDoctors,
    totalCases,
    totalTickets,
    pendingCases,
    statusGroups,
    casesPerMonth,
    weeklyNewUsers,
  ] = await Promise.all([
    prisma.user.count(),
    prisma.doctor.count(),
    prisma.case.count({ where: hasDateFilter ? { createdAt: dateFilter } : undefined }),
    prisma.ticket.count(),
    prisma.case.count({ where: { status: 'PENDING' } }),
    prisma.case.groupBy({ by: ['status'], _count: { _all: true } }),
    prisma.$queryRaw`
      SELECT to_char(date_trunc('month', "createdAt"), 'YYYY-MM') as month,
             COUNT(*)::int as count
      FROM "Case"
      WHERE "createdAt" >= ${sixMonthsAgo}
      GROUP BY 1
      ORDER BY 1 ASC
    `,
    prisma.$queryRaw`
      SELECT to_char(date_trunc('week', "createdAt"), 'YYYY-MM-DD') as week,
             COUNT(*)::int as count
      FROM "User"
      WHERE "createdAt" >= ${eightWeeksAgo}
      GROUP BY 1
      ORDER BY 1 ASC
    `,
  ]);

  const statusDistribution = statusGroups.reduce((acc, row) => {
    acc[row.status] = row._count._all;
    return acc;
  }, {});

  res.json({
    totals: { totalUsers, totalDoctors, totalCases, totalTickets, pendingCases },
    casesPerMonth,
    statusDistribution,
    weeklyNewUsers,
  });
});

// ---------------------------------------------------------------------------
// Cases
// ---------------------------------------------------------------------------

// GET /api/admin/cases?status&doctorId&search&from&to&page
const listCases = asyncHandler(async (req, res) => {
  const { status, doctorId, search, from, to, page: pageQuery, limit: limitQuery } = req.query;
  const { page, limit, skip, take } = getPagination({ page: pageQuery, limit: limitQuery });
  const where = buildCaseFilter({ status, doctorId, search, from, to });

  const [data, total] = await Promise.all([
    prisma.case.findMany({
      where,
      skip,
      take,
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, name: true, phone: true, avatar: true } },
        doctor: { select: { id: true, name: true, specialization: true } },
      },
    }),
    prisma.case.count({ where }),
  ]);

  res.json(buildPaginatedResponse(data, total, page, limit));
});

// GET /api/admin/cases/export?status&doctorId&search&from&to
const exportCases = asyncHandler(async (req, res) => {
  const { status, doctorId, search, from, to } = req.query;
  const where = buildCaseFilter({ status, doctorId, search, from, to });

  const cases = await prisma.case.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    include: {
      user: { select: { name: true, phone: true } },
      doctor: { select: { name: true } },
    },
  });

  const header = ['Case ID', 'User', 'Phone', 'Doctor', 'Status', 'Created At'];
  const rows = cases.map((c) => [
    c.id,
    c.user?.name,
    c.user?.phone,
    c.doctor?.name || '',
    c.status,
    c.createdAt.toISOString(),
  ]);
  const csv = toCsv(header, rows);

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', `attachment; filename="cases-${Date.now()}.csv"`);
  res.send(csv);
});

// GET /api/admin/cases/:id
const getCaseById = asyncHandler(async (req, res) => {
  const found = await prisma.case.findUnique({
    where: { id: req.params.id },
    include: {
      user: { select: { id: true, name: true, phone: true, email: true, avatar: true, gender: true, age: true } },
      doctor: { select: { id: true, name: true, specialization: true, avatar: true, experience: true } },
      questionFlow: true,
      solution: true,
      videoCalls: true,
      statusHistory: { orderBy: { createdAt: 'asc' } },
      _count: { select: { messages: true } },
    },
  });

  if (!found) throw ApiError.notFound('Case not found');
  res.json({ case: found });
});

// PATCH /api/admin/cases/:id/assign
const assignCase = asyncHandler(async (req, res) => {
  const { doctorId } = req.body;

  const [caseRecord, doctor] = await Promise.all([
    prisma.case.findUnique({ where: { id: req.params.id } }),
    prisma.doctor.findUnique({ where: { id: doctorId } }),
  ]);
  if (!caseRecord) throw ApiError.notFound('Case not found');
  if (!doctor) throw ApiError.badRequest('Invalid doctorId');
  if (!doctor.isAvailable) throw ApiError.badRequest(`Dr. ${doctor.name} is not available for new cases`);
  if (['SOLVED', 'CLOSED'].includes(caseRecord.status)) {
    throw ApiError.badRequest(`A ${caseRecord.status.toLowerCase()} case cannot be reassigned`);
  }

  const updated = await prisma.case.update({
    where: { id: caseRecord.id },
    data: { doctorId, status: 'ASSIGNED' },
  });

  await recordCaseStatus({
    caseId: updated.id,
    status: 'ASSIGNED',
    changedByType: 'ADMIN',
    changedById: req.admin.id,
    note: `Assigned to ${doctor.name}`,
  });

  await prisma.notification.create({
    data: {
      userId: doctorId,
      userType: 'DOCTOR',
      title: 'New case assigned',
      body: `A new case has been assigned to you.`,
      type: 'CASE_ASSIGNED',
      caseId: updated.id,
    },
  });

  await fcm.sendPushNotification({
    title: 'New case assigned',
    body: 'A new case has been assigned to you.',
    data: { caseId: caseRecord.id, type: 'CASE_ASSIGNED' },
  });

  const patientNotice = {
    title: 'Doctor assigned',
    body: `Dr. ${doctor.name} will review your case.`,
    type: 'CASE_ASSIGNED',
    caseId: caseRecord.id,
  };
  await prisma.notification.create({ data: { ...patientNotice, userId: caseRecord.userId, userType: 'USER' } });

  const payload = { caseId: caseRecord.id, doctor: sanitize(doctor) };
  socket.emitToDoctor(doctorId, 'case_assigned', payload);
  socket.emitToCase(caseRecord.id, 'case_assigned', payload);
  socket.emitToUser(caseRecord.userId, 'case_assigned', payload);
  socket.emitToUser(caseRecord.userId, 'notification', patientNotice);

  res.json({ case: updated });
});

// SOLVED is deliberately absent: only a doctor's solution submission may mark
// a case solved, otherwise the patient sees "Solved" with no prescription.
const ADMIN_STATUS_TRANSITIONS = {
  PENDING: [],
  ASSIGNED: ['IN_REVIEW', 'CLOSED'],
  IN_REVIEW: ['CLOSED'],
  SOLVED: ['CLOSED'],
  CLOSED: [],
};

// PATCH /api/admin/cases/:id/status
const updateCaseStatus = asyncHandler(async (req, res) => {
  const { status } = req.body;

  const caseRecord = await prisma.case.findUnique({ where: { id: req.params.id } });
  if (!caseRecord) throw ApiError.notFound('Case not found');
  if (!ADMIN_STATUS_TRANSITIONS[caseRecord.status].includes(status)) {
    throw ApiError.badRequest(`Cannot change case status from ${caseRecord.status} to ${status}`);
  }

  const updated = await prisma.case.update({ where: { id: caseRecord.id }, data: { status } });

  await recordCaseStatus({
    caseId: updated.id,
    status,
    changedByType: 'ADMIN',
    changedById: req.admin.id,
  });

  const payload = { caseId: updated.id, status };
  socket.emitToUser(updated.userId, 'case_status_changed', payload);
  if (updated.doctorId) socket.emitToDoctor(updated.doctorId, 'case_status_changed', payload);

  res.json({ case: updated });
});

// ---------------------------------------------------------------------------
// Doctors
// ---------------------------------------------------------------------------

// GET /api/admin/doctors?search&page
const listDoctors = asyncHandler(async (req, res) => {
  const { search, page: pageQuery, limit: limitQuery } = req.query;
  const { page, limit, skip, take } = getPagination({ page: pageQuery, limit: limitQuery });

  const where = search
    ? {
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { email: { contains: search, mode: 'insensitive' } },
          { specialization: { contains: search, mode: 'insensitive' } },
        ],
      }
    : undefined;

  const [doctors, total] = await Promise.all([
    prisma.doctor.findMany({
      where,
      skip,
      take,
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { cases: true } } },
    }),
    prisma.doctor.count({ where }),
  ]);

  const [solvedCounts, ratingGroups] = doctors.length
    ? await Promise.all([
        prisma.case.groupBy({
          by: ['doctorId'],
          where: { doctorId: { in: doctors.map((d) => d.id) }, status: { in: ['SOLVED', 'CLOSED'] } },
          _count: { _all: true },
        }),
        prisma.rating.groupBy({
          by: ['doctorId'],
          where: { doctorId: { in: doctors.map((d) => d.id) } },
          _avg: { score: true },
          _count: { _all: true },
        }),
      ])
    : [[], []];
  const solvedByDoctor = solvedCounts.reduce((acc, row) => {
    acc[row.doctorId] = row._count._all;
    return acc;
  }, {});
  const ratingByDoctor = ratingGroups.reduce((acc, row) => {
    acc[row.doctorId] = { avgRating: row._avg.score, reviewCount: row._count._all };
    return acc;
  }, {});

  const shaped = doctors.map((doctor) => ({
    ...sanitize(doctor),
    totalCases: doctor._count.cases,
    solvedCases: solvedByDoctor[doctor.id] || 0,
    avgRating: ratingByDoctor[doctor.id]?.avgRating ?? null,
    reviewCount: ratingByDoctor[doctor.id]?.reviewCount || 0,
  }));

  res.json(buildPaginatedResponse(shaped, total, page, limit));
});

// GET /api/admin/doctors/:id
const getDoctorById = asyncHandler(async (req, res) => {
  const doctor = await prisma.doctor.findUnique({ where: { id: req.params.id } });
  if (!doctor) throw ApiError.notFound('Doctor not found');

  const [statusGroups, ratingAgg] = await Promise.all([
    prisma.case.groupBy({
      by: ['status'],
      where: { doctorId: doctor.id },
      _count: { _all: true },
    }),
    prisma.rating.aggregate({ where: { doctorId: doctor.id }, _avg: { score: true }, _count: { _all: true } }),
  ]);
  const casesByStatus = statusGroups.reduce((acc, row) => {
    acc[row.status] = row._count._all;
    return acc;
  }, {});

  res.json({
    doctor: { ...sanitize(doctor), avgRating: ratingAgg._avg.score, reviewCount: ratingAgg._count._all },
    casesByStatus,
  });
});

// POST /api/admin/doctors
const createDoctor = asyncHandler(async (req, res) => {
  const { name, email, phone, specialization, experience } = req.body;

  const existingEmail = await prisma.doctor.findUnique({ where: { email } });
  if (existingEmail) throw ApiError.conflict('A doctor with this email already exists');

  const existingPhone = await prisma.doctor.findUnique({ where: { phone } });
  if (existingPhone) throw ApiError.conflict('A doctor with this phone number already exists');

  // No password: doctors log in with phone+OTP, the same flow as Users (see
  // auth.controller.js's verifyOtp) - this phone number IS their login.
  const doctor = await prisma.doctor.create({
    data: { name, email, phone, specialization, experience },
  });

  res.status(201).json({ doctor: sanitize(doctor) });
});

// PUT /api/admin/doctors/:id
const updateDoctor = asyncHandler(async (req, res) => {
  const { name, email, phone, specialization, experience, isAvailable, avatar } = req.body;

  const existing = await prisma.doctor.findUnique({ where: { id: req.params.id } });
  if (!existing) throw ApiError.notFound('Doctor not found');

  const data = {
    ...(name !== undefined && { name }),
    ...(email !== undefined && { email }),
    ...(phone !== undefined && { phone }),
    ...(specialization !== undefined && { specialization }),
    ...(experience !== undefined && { experience }),
    ...(isAvailable !== undefined && { isAvailable }),
    ...(avatar !== undefined && { avatar }),
  };

  const doctor = await prisma.doctor.update({ where: { id: existing.id }, data });
  res.json({ doctor: sanitize(doctor) });
});

// DELETE /api/admin/doctors/:id
const deleteDoctor = asyncHandler(async (req, res) => {
  const existing = await prisma.doctor.findUnique({ where: { id: req.params.id } });
  if (!existing) throw ApiError.notFound('Doctor not found');

  // Deleting nulls Case.doctorId; without this, an in-progress case would be
  // stranded as ASSIGNED with no doctor and never resurface for reassignment.
  const activeCases = await prisma.case.findMany({
    where: { doctorId: existing.id, status: { in: ['ASSIGNED', 'IN_REVIEW'] } },
    select: { id: true },
  });

  await prisma.$transaction([
    prisma.case.updateMany({
      where: { id: { in: activeCases.map((c) => c.id) } },
      data: { status: 'PENDING' },
    }),
    prisma.doctor.delete({ where: { id: existing.id } }),
  ]);

  for (const c of activeCases) {
    await recordCaseStatus({
      caseId: c.id,
      status: 'PENDING',
      changedByType: 'ADMIN',
      changedById: req.admin.id,
      note: `Returned to queue: Dr. ${existing.name} was removed`,
    });
  }

  res.status(204).send();
});

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

// GET /api/admin/users?search&page
const listUsers = asyncHandler(async (req, res) => {
  const { search, page: pageQuery, limit: limitQuery } = req.query;
  const { page, limit, skip, take } = getPagination({ page: pageQuery, limit: limitQuery });

  const where = search
    ? {
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { phone: { contains: search, mode: 'insensitive' } },
          { email: { contains: search, mode: 'insensitive' } },
        ],
      }
    : undefined;

  const [data, total] = await Promise.all([
    prisma.user.findMany({ where, skip, take, orderBy: { createdAt: 'desc' } }),
    prisma.user.count({ where }),
  ]);

  res.json(buildPaginatedResponse(data, total, page, limit));
});

// GET /api/admin/users/:id
const getUserById = asyncHandler(async (req, res) => {
  const user = await prisma.user.findUnique({ where: { id: req.params.id } });
  if (!user) throw ApiError.notFound('User not found');

  const cases = await prisma.case.findMany({
    where: { userId: user.id },
    orderBy: { createdAt: 'desc' },
    select: { id: true, status: true, createdAt: true, doctor: { select: { id: true, name: true } } },
  });

  res.json({ user, cases });
});

// PUT /api/admin/users/:id
const updateUser = asyncHandler(async (req, res) => {
  const { isBlocked } = req.body;

  const existing = await prisma.user.findUnique({ where: { id: req.params.id } });
  if (!existing) throw ApiError.notFound('User not found');

  const user = await prisma.user.update({ where: { id: existing.id }, data: { isBlocked } });
  res.json({ user });
});

// ---------------------------------------------------------------------------
// Tickets
// ---------------------------------------------------------------------------

// GET /api/admin/tickets?status&priority
const listTickets = asyncHandler(async (req, res) => {
  const { status, priority } = req.query;
  const where = { ...(status && { status }), ...(priority && { priority }) };

  const tickets = await prisma.ticket.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    include: { user: { select: { id: true, name: true, phone: true, avatar: true } } },
  });

  res.json({ data: tickets });
});

// PATCH /api/admin/tickets/:id
const updateTicket = asyncHandler(async (req, res) => {
  const { status, reply } = req.body;

  const existing = await prisma.ticket.findUnique({ where: { id: req.params.id } });
  if (!existing) throw ApiError.notFound('Ticket not found');

  const ticket = await prisma.ticket.update({
    where: { id: existing.id },
    data: {
      ...(status !== undefined && { status }),
      ...(reply !== undefined && { reply }),
    },
  });

  const notice = {
    title: 'Support ticket updated',
    body: reply ? 'Support replied to your ticket.' : `Your ticket status changed to ${ticket.status}.`,
    type: 'TICKET_UPDATE',
  };
  await prisma.notification.create({ data: { ...notice, userId: ticket.userId, userType: 'USER' } });
  socket.emitToUser(ticket.userId, 'notification', notice);

  res.json({ ticket });
});

// ---------------------------------------------------------------------------
// Question flows
// ---------------------------------------------------------------------------

// GET /api/admin/question-flows
const listQuestionFlows = asyncHandler(async (req, res) => {
  const flows = await prisma.questionFlow.findMany({ orderBy: { createdAt: 'desc' } });
  res.json({ data: flows });
});

// POST /api/admin/question-flows
const createQuestionFlow = asyncHandler(async (req, res) => {
  const { title, questions } = req.body;
  const flow = await prisma.questionFlow.create({ data: { title, questions, isActive: false } });
  res.status(201).json({ questionFlow: flow });
});

// PUT /api/admin/question-flows/:id
// Business rule: only one QuestionFlow can be active at a time. Activating
// this one deactivates every other flow, atomically.
const updateQuestionFlow = asyncHandler(async (req, res) => {
  const { title, questions, isActive } = req.body;

  const existing = await prisma.questionFlow.findUnique({ where: { id: req.params.id } });
  if (!existing) throw ApiError.notFound('Question flow not found');

  const data = {
    ...(title !== undefined && { title }),
    ...(questions !== undefined && { questions }),
  };

  let updated;
  if (isActive === true) {
    const [, flow] = await prisma.$transaction([
      prisma.questionFlow.updateMany({ where: { id: { not: existing.id } }, data: { isActive: false } }),
      prisma.questionFlow.update({ where: { id: existing.id }, data: { ...data, isActive: true } }),
    ]);
    updated = flow;
  } else {
    updated = await prisma.questionFlow.update({
      where: { id: existing.id },
      data: { ...data, ...(isActive !== undefined && { isActive }) },
    });
  }

  res.json({ questionFlow: updated });
});

// DELETE /api/admin/question-flows/:id
const deleteQuestionFlow = asyncHandler(async (req, res) => {
  const existing = await prisma.questionFlow.findUnique({ where: { id: req.params.id } });
  if (!existing) throw ApiError.notFound('Question flow not found');

  await prisma.questionFlow.delete({ where: { id: existing.id } });
  res.status(204).send();
});

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

// POST /api/admin/notifications/send
const sendNotification = asyncHandler(async (req, res) => {
  const { title, body, target, targetId } = req.body;

  if ((target === 'SPECIFIC_USER' || target === 'SPECIFIC_DOCTOR') && !targetId) {
    throw ApiError.badRequest('targetId is required for this target type');
  }

  switch (target) {
    case 'ALL_USERS': {
      const users = await prisma.user.findMany({ select: { id: true } });
      if (users.length) {
        await prisma.notification.createMany({
          data: users.map((u) => ({ userId: u.id, userType: 'USER', title, body, type: 'ADMIN_BROADCAST' })),
        });
      }
      await fcm.sendPushToTopic({ topic: 'all-users', title, body });
      socket.emitToAllUsers('notification', { title, body, type: 'ADMIN_BROADCAST' });
      break;
    }
    case 'ALL_DOCTORS': {
      const doctors = await prisma.doctor.findMany({ select: { id: true } });
      if (doctors.length) {
        await prisma.notification.createMany({
          data: doctors.map((d) => ({ userId: d.id, userType: 'DOCTOR', title, body, type: 'ADMIN_BROADCAST' })),
        });
      }
      await fcm.sendPushToTopic({ topic: 'all-doctors', title, body });
      socket.emitToAllDoctors('notification', { title, body, type: 'ADMIN_BROADCAST' });
      break;
    }
    case 'SPECIFIC_USER': {
      const user = await prisma.user.findUnique({ where: { id: targetId } });
      if (!user) throw ApiError.badRequest('Invalid targetId: user not found');
      await prisma.notification.create({
        data: { userId: targetId, userType: 'USER', title, body, type: 'ADMIN_BROADCAST' },
      });
      await fcm.sendPushNotification({ title, body, data: { type: 'ADMIN_BROADCAST' } });
      socket.emitToUser(targetId, 'notification', { title, body, type: 'ADMIN_BROADCAST' });
      break;
    }
    case 'SPECIFIC_DOCTOR': {
      const doctor = await prisma.doctor.findUnique({ where: { id: targetId } });
      if (!doctor) throw ApiError.badRequest('Invalid targetId: doctor not found');
      await prisma.notification.create({
        data: { userId: targetId, userType: 'DOCTOR', title, body, type: 'ADMIN_BROADCAST' },
      });
      await fcm.sendPushNotification({ title, body, data: { type: 'ADMIN_BROADCAST' } });
      socket.emitToDoctor(targetId, 'notification', { title, body, type: 'ADMIN_BROADCAST' });
      break;
    }
    default:
      throw ApiError.badRequest('Invalid target');
  }

  res.status(201).json({ success: true });
});

// GET /api/admin/notifications?page&limit
const listNotifications = asyncHandler(async (req, res) => {
  const { page: pageQuery, limit: limitQuery } = req.query;
  const { page, limit, skip, take } = getPagination({ page: pageQuery, limit: limitQuery });

  const [data, total] = await Promise.all([
    prisma.notification.findMany({ skip, take, orderBy: { createdAt: 'desc' } }),
    prisma.notification.count(),
  ]);

  res.json(buildPaginatedResponse(data, total, page, limit));
});

// ---------------------------------------------------------------------------
// Video calls
// ---------------------------------------------------------------------------

// GET /api/admin/video-calls?status
const listVideoCalls = asyncHandler(async (req, res) => {
  const { status } = req.query;
  const where = status ? { status } : undefined;

  const videoCalls = await prisma.videoCall.findMany({
    where,
    orderBy: { scheduledAt: 'desc' },
    include: {
      case: {
        select: {
          id: true,
          user: { select: { id: true, name: true } },
          doctor: { select: { id: true, name: true } },
        },
      },
    },
  });

  res.json({ data: videoCalls });
});

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

// GET /api/admin/reports?type&from&to
const getReports = asyncHandler(async (req, res) => {
  const { type = 'cases', from, to } = req.query;

  const dateFilter = {};
  if (from) dateFilter.gte = new Date(from);
  if (to) dateFilter.lte = new Date(to);
  const createdAt = Object.keys(dateFilter).length ? dateFilter : undefined;

  let data;
  switch (type) {
    case 'cases':
      data = await prisma.case.findMany({
        where: { ...(createdAt && { createdAt }) },
        include: {
          user: { select: { id: true, name: true } },
          doctor: { select: { id: true, name: true } },
        },
        orderBy: { createdAt: 'desc' },
      });
      break;
    case 'users':
      data = await prisma.user.findMany({
        where: { ...(createdAt && { createdAt }) },
        orderBy: { createdAt: 'desc' },
      });
      break;
    case 'doctors':
      data = (
        await prisma.doctor.findMany({
          where: { ...(createdAt && { createdAt }) },
          orderBy: { createdAt: 'desc' },
        })
      ).map(sanitize);
      break;
    case 'tickets':
      data = await prisma.ticket.findMany({
        where: { ...(createdAt && { createdAt }) },
        orderBy: { createdAt: 'desc' },
      });
      break;
    default:
      throw ApiError.badRequest('Invalid report type. Use one of: cases, users, doctors, tickets');
  }

  res.json({ type, from: from || null, to: to || null, count: data.length, data });
});

module.exports = {
  getProfile,
  updateProfile,
  changePassword,
  getAnalytics,
  listCases,
  exportCases,
  getCaseById,
  assignCase,
  updateCaseStatus,
  listDoctors,
  getDoctorById,
  createDoctor,
  updateDoctor,
  deleteDoctor,
  listUsers,
  getUserById,
  updateUser,
  listTickets,
  updateTicket,
  listQuestionFlows,
  createQuestionFlow,
  updateQuestionFlow,
  deleteQuestionFlow,
  sendNotification,
  listNotifications,
  listVideoCalls,
  getReports,
};
