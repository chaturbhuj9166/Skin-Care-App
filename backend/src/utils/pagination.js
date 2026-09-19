const DEFAULT_PAGE = 1;
const DEFAULT_LIMIT = 20;

/**
 * Reads `page`/`limit` off a request query object and returns safe,
 * normalized values plus the `skip`/`take` pair Prisma expects.
 */
function getPagination(query = {}) {
  let page = parseInt(query.page, 10);
  let limit = parseInt(query.limit, 10);

  if (!Number.isFinite(page) || page < 1) page = DEFAULT_PAGE;
  if (!Number.isFinite(limit) || limit < 1) limit = DEFAULT_LIMIT;
  if (limit > 100) limit = 100; // sane upper bound

  const skip = (page - 1) * limit;
  return { page, limit, skip, take: limit };
}

/**
 * Shapes a paginated Prisma result into the standard API envelope:
 * { data, total, page, totalPages }
 */
function buildPaginatedResponse(data, total, page, limit) {
  return {
    data,
    total,
    page,
    totalPages: limit > 0 ? Math.ceil(total / limit) : 0,
  };
}

module.exports = { getPagination, buildPaginatedResponse };
