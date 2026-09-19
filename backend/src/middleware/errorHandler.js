const { Prisma } = require('@prisma/client');
const ApiError = require('../utils/ApiError');

// Translates known Prisma error codes into sane HTTP responses instead of
// leaking a 500 + stack trace for everyday cases like unique constraint
// violations or "record not found".
function mapPrismaError(err) {
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    switch (err.code) {
      case 'P2002': {
        const target = Array.isArray(err.meta?.target) ? err.meta.target.join(', ') : err.meta?.target;
        return ApiError.conflict(`A record with this ${target || 'value'} already exists`);
      }
      case 'P2025':
        return ApiError.notFound('Record not found');
      case 'P2003':
        return ApiError.conflict('This action violates a data relationship (referenced record still in use)');
      default:
        return null;
    }
  }
  return null;
}

// 404 handler for unmatched routes. Mount after all routes, before errorHandler.
function notFoundHandler(req, res, next) {
  next(ApiError.notFound(`Route not found: ${req.method} ${req.originalUrl}`));
}

// Central Express error-handling middleware. Must be mounted last.
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  let apiError = err instanceof ApiError ? err : mapPrismaError(err);

  if (!apiError) {
    console.error('[unhandled error]', err);
    apiError = new ApiError(500, 'Internal server error');
  } else if (apiError.statusCode >= 500) {
    console.error('[error]', err);
  }

  res.status(apiError.statusCode).json({
    error: apiError.message,
    ...(apiError.details ? { details: apiError.details } : {}),
  });
}

module.exports = { errorHandler, notFoundHandler };
