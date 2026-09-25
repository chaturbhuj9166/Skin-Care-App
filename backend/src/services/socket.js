// Socket.io real-time layer: chat messages + live notifications.
//
// Every socket connection must authenticate with the same JWT used for the
// REST API (passed as `auth: { token }` on the client, or a `token` query
// param). Once authenticated, a socket auto-joins two rooms:
//   - a role-wide room ("USER" | "DOCTOR" | "ADMIN") used to broadcast to
//     every connected member of that role (e.g. admin notification blasts)
//   - a personal room ("USER:<id>" | "DOCTOR:<id>" | "ADMIN:<id>") used to
//     target one specific user/doctor/admin (e.g. "your case was assigned")
//
// REST controllers reach into this module's emit* helpers to push
// server -> client events (case_assigned, solution_added, call_scheduled,
// notification) whenever the corresponding action happens over HTTP.
const { Server } = require('socket.io');
const prisma = require('../config/db');
const env = require('../config/env');
const { verifyToken, ROLES } = require('../utils/jwt');

let io = null;

function roleRoom(role) {
  return String(role).toUpperCase();
}

function personalRoom(role, id) {
  return `${roleRoom(role)}:${id}`;
}

function caseRoom(caseId) {
  return `case_${caseId}`;
}

function authenticateSocket(socket, next) {
  const token =
    socket.handshake.auth?.token ||
    socket.handshake.query?.token ||
    (socket.handshake.headers.authorization || '').split(' ')[1];

  if (!token) {
    return next(new Error('Authentication required'));
  }

  try {
    const payload = verifyToken(token);
    socket.data.userId = payload.id;
    socket.data.role = payload.role;
    next();
  } catch (err) {
    next(new Error('Invalid or expired token'));
  }
}

// A socket may only join/write to a case's chat room if its identity is the
// case's own patient or assigned doctor (or an admin, for support access).
// Without this, any authenticated user could guess/enumerate a caseId and
// read or post into someone else's consultation.
async function canAccessCase(caseId, userId, role) {
  if (role === ROLES.ADMIN) return true;
  const caseRecord = await prisma.case.findUnique({ where: { id: caseId }, select: { userId: true, doctorId: true } });
  if (!caseRecord) return false;
  if (role === ROLES.USER) return caseRecord.userId === userId;
  if (role === ROLES.DOCTOR) return caseRecord.doctorId === userId;
  return false;
}

function registerHandlers(socket) {
  const { userId, role } = socket.data;

  // Auto-join the rooms this identity is allowed to receive broadcasts on.
  socket.join(roleRoom(role));
  socket.join(personalRoom(role, userId));

  socket.on('join_case', async ({ caseId } = {}) => {
    if (!caseId) return;
    if (!(await canAccessCase(caseId, userId, role))) {
      socket.emit('error', { event: 'join_case', message: 'Not authorized for this case' });
      return;
    }
    socket.join(caseRoom(caseId));
  });

  socket.on('send_message', async ({ caseId, text, fileUrl } = {}) => {
    try {
      if (!caseId || (!text && !fileUrl)) return;
      if (role !== ROLES.USER && role !== ROLES.DOCTOR) return;
      if (!(await canAccessCase(caseId, userId, role))) {
        socket.emit('error', { event: 'send_message', message: 'Not authorized for this case' });
        return;
      }

      const message = await prisma.message.create({
        data: {
          caseId,
          senderId: userId,
          senderType: role,
          text: text || null,
          fileUrl: fileUrl || null,
        },
      });

      io.to(caseRoom(caseId)).emit('new_message', message);
    } catch (err) {
      console.error('[socket] send_message failed:', err.message);
      socket.emit('error', { event: 'send_message', message: 'Failed to send message' });
    }
  });

  socket.on('typing', ({ caseId, senderType } = {}) => {
    if (!caseId) return;
    socket.to(caseRoom(caseId)).emit('typing', { caseId, senderType: senderType || role });
  });

  socket.on('stop_typing', ({ caseId } = {}) => {
    if (!caseId) return;
    socket.to(caseRoom(caseId)).emit('stop_typing', { caseId });
  });
}

function initSocket(httpServer) {
  io = new Server(httpServer, {
    cors: { origin: env.CORS_ORIGIN, methods: ['GET', 'POST'] },
  });

  io.use(authenticateSocket);
  io.on('connection', (socket) => registerHandlers(socket));

  return io;
}

function getIO() {
  if (!io) {
    throw new Error('Socket.io has not been initialized yet. Call initSocket(httpServer) first.');
  }
  return io;
}

// ---------------------------------------------------------------------------
// Emit helpers used by REST controllers
// ---------------------------------------------------------------------------

// Diagnostic only: a room with 0 sockets means the emit was a no-op (the
// recipient's app has no live socket connection right now, e.g. backgrounded
// on mobile) - useful to tell apart from "the emit call never ran at all"
// when a real-time alert doesn't show up on a test device.
function connectedCount(room) {
  return getIO().sockets.adapter.rooms.get(room)?.size ?? 0;
}

function emitToUser(userId, event, payload) {
  const room = personalRoom(ROLES.USER, userId);
  console.log(`[socket] emitToUser ${userId} '${event}' -> ${connectedCount(room)} connected socket(s)`);
  getIO().to(room).emit(event, payload);
}

function emitToDoctor(doctorId, event, payload) {
  const room = personalRoom(ROLES.DOCTOR, doctorId);
  console.log(`[socket] emitToDoctor ${doctorId} '${event}' -> ${connectedCount(room)} connected socket(s)`);
  getIO().to(room).emit(event, payload);
}

function emitToAdmin(adminId, event, payload) {
  getIO().to(personalRoom(ROLES.ADMIN, adminId)).emit(event, payload);
}

function emitToAllUsers(event, payload) {
  getIO().to(roleRoom(ROLES.USER)).emit(event, payload);
}

function emitToAllDoctors(event, payload) {
  getIO().to(roleRoom(ROLES.DOCTOR)).emit(event, payload);
}

function emitToAllAdmins(event, payload) {
  getIO().to(roleRoom(ROLES.ADMIN)).emit(event, payload);
}

function emitToCase(caseId, event, payload) {
  getIO().to(caseRoom(caseId)).emit(event, payload);
}

module.exports = {
  initSocket,
  getIO,
  emitToUser,
  emitToDoctor,
  emitToAdmin,
  emitToAllUsers,
  emitToAllDoctors,
  emitToAllAdmins,
  emitToCase,
};
