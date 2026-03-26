import * as jose from 'jose';

export const authMiddleware = async (c, next) => {
  const authHeader = c.req.header('Authorization');

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return c.json({ error: 'Unauthorized' }, 401);
  }

  try {
    const token = authHeader.slice(7);
    const secret = new TextEncoder().encode(c.env.JWT_SECRET);
    const { payload } = await jose.jwtVerify(token, secret);
    c.set('userId', payload.userId);
    c.set('username', payload.username);
    await next();
  } catch {
    return c.json({ error: 'Unauthorized' }, 401);
  }
};