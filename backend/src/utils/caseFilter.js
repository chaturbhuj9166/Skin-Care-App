// Builds the Prisma `where` clause shared by the admin case list and CSV
// export endpoints, so both stay in sync on filter semantics.
function buildCaseFilter({ status, doctorId, search, from, to }) {
  const where = {
    ...(status && { status }),
    ...(doctorId && { doctorId }),
  };

  const createdAt = {};
  if (from) createdAt.gte = new Date(from);
  if (to) createdAt.lte = new Date(to);
  if (Object.keys(createdAt).length) where.createdAt = createdAt;

  if (search) {
    where.user = {
      OR: [
        { name: { contains: search, mode: 'insensitive' } },
        { phone: { contains: search, mode: 'insensitive' } },
      ],
    };
  }

  return where;
}

module.exports = { buildCaseFilter };
