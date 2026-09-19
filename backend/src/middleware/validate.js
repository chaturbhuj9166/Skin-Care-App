// Lightweight request validation using zod. Usage:
//   router.post('/x', validate({ body: someZodSchema }), controller.x)
// Validated/parsed data is written back onto req.body / req.query / req.params
// so downstream handlers get coerced, defaulted values.
function validate(schemas) {
  return (req, res, next) => {
    for (const key of ['body', 'query', 'params']) {
      const schema = schemas[key];
      if (!schema) continue;

      const result = schema.safeParse(req[key]);
      if (!result.success) {
        return res.status(400).json({
          error: 'Validation failed',
          location: key,
          details: result.error.flatten(),
        });
      }
      req[key] = result.data;
    }
    next();
  };
}

module.exports = validate;
