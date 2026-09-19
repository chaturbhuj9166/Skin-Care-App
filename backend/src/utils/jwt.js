const jwt = require('jsonwebtoken');
const env = require('../config/env');

/**
 * Roles carried inside the JWT payload. Kept as plain strings (rather than a
 * Prisma enum) since Admin/User/Doctor are separate models, not rows in one
 * table with a role column.
 */
const ROLES = {
  ADMIN: 'ADMIN',
  USER: 'USER',
  DOCTOR: 'DOCTOR',
};

function signToken({ id, role }) {
  return jwt.sign({ id, role }, env.JWT_SECRET, { expiresIn: env.JWT_EXPIRES_IN });
}

function verifyToken(token) {
  return jwt.verify(token, env.JWT_SECRET);
}

module.exports = { signToken, verifyToken, ROLES };
