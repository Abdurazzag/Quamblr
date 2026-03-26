import { Hono } from 'hono';
import bcrypt from 'bcryptjs';
import * as jose from 'jose';

const auth = new Hono();

// --- POST /auth/register ---
auth.post('/register', async (c) => {
  const body = await c.req.json();
  const { username, password } = body;

  if (!username || !password) {
    return c.json({ error: 'All fields are required' }, 400);
  }

  if (password.length < 8) {
    return c.json({ error: 'Password must be at least 8 characters' }, 400);
  }

  const existing = await c.env.DB.prepare(
    'SELECT userId FROM users WHERE username = ?'
  )
    .bind(username)
    .first();

  if (existing) {
    return c.json({ error: 'Username already taken' }, 409);
  }

  const hashedPassword = bcrypt.hashSync(password, 10);

  await c.env.DB.prepare(
    'INSERT INTO users (username, password, createdAt) VALUES (?, ?, datetime("now"))'
  )
    .bind(username, hashedPassword)
    .run();

  const newUser = await c.env.DB.prepare(
    'SELECT userId FROM users WHERE username = ?'
  )
    .bind(username)
    .first();

  // Issue tokens immediately on registration
  const secret = new TextEncoder().encode(c.env.JWT_SECRET);

  const accessToken = await new jose.SignJWT({
    userId: newUser.userId,
    username: username,
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('1h')
    .sign(secret);

  const refreshToken = await new jose.SignJWT({
    userId: newUser.userId,
    type: 'refresh',
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('60d')
    .sign(secret);

  const refreshExpiry = new Date(
    Date.now() + 60 * 24 * 60 * 60 * 1000
  ).toISOString();

  await c.env.DB.prepare(
    'INSERT INTO refresh_tokens (userId, token, expiresAt, createdAt) VALUES (?, ?, ?, datetime("now"))'
  )
    .bind(newUser.userId, refreshToken, refreshExpiry)
    .run();

  return c.json(
    {
      accessToken,
      refreshToken,
      user: {
        userId: newUser.userId,
        username: username,
      },
    },
    201
  );
});

// --- POST /auth/login ---
auth.post('/login', async (c) => {
  const body = await c.req.json();
  const { username, password } = body;

  if (!username || !password) {
    return c.json({ error: 'Username and password are required' }, 400);
  }

  const user = await c.env.DB.prepare('SELECT * FROM users WHERE username = ?')
    .bind(username)
    .first();

  if (!user) {
    return c.json({ error: 'Invalid credentials' }, 401);
  }

  const passwordMatch = bcrypt.compareSync(password, user.password);
  if (!passwordMatch) {
    return c.json({ error: 'Invalid credentials' }, 401);
  }

  const secret = new TextEncoder().encode(c.env.JWT_SECRET);

  const accessToken = await new jose.SignJWT({
    userId: user.userId,
    username: user.username,
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('1h')
    .sign(secret);

  const refreshToken = await new jose.SignJWT({
    userId: user.userId,
    type: 'refresh',
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('60d')
    .sign(secret);

  const refreshExpiry = new Date(
    Date.now() + 60 * 24 * 60 * 60 * 1000
  ).toISOString();

  await c.env.DB.prepare(
    'INSERT INTO refresh_tokens (userId, token, expiresAt, createdAt) VALUES (?, ?, ?, datetime("now"))'
  )
    .bind(user.userId, refreshToken, refreshExpiry)
    .run();

  return c.json({
    accessToken,
    refreshToken,
    user: {
      userId: user.userId,
      username: user.username,
    },
  });
});

// --- POST /auth/refresh ---
auth.post('/refresh', async (c) => {
  const body = await c.req.json();
  const { refreshToken } = body;

  if (!refreshToken) {
    return c.json({ error: 'Refresh token is required' }, 400);
  }

  const stored = await c.env.DB.prepare(
    'SELECT * FROM refresh_tokens WHERE token = ? AND expiresAt > datetime("now")'
  )
    .bind(refreshToken)
    .first();

  if (!stored) {
    return c.json({ error: 'Invalid or expired refresh token' }, 401);
  }

  const user = await c.env.DB.prepare(
    'SELECT userId, username FROM users WHERE userId = ?'
  )
    .bind(stored.userId)
    .first();

  const secret = new TextEncoder().encode(c.env.JWT_SECRET);
  const accessToken = await new jose.SignJWT({
    userId: user.userId,
    username: user.username,
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('1h')
    .sign(secret);

  return c.json({ accessToken });
});

// --- POST /auth/logout ---
auth.post('/logout', async (c) => {
  const body = await c.req.json();
  const { refreshToken } = body;

  if (!refreshToken) {
    return c.json({ error: 'Refresh token is required' }, 400);
  }

  await c.env.DB.prepare('DELETE FROM refresh_tokens WHERE token = ?')
    .bind(refreshToken)
    .run();

  return c.json({ message: 'Logged out successfully' });
});

export default auth;
