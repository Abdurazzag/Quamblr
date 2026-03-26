import { Hono } from 'hono';
import { authMiddleware } from '../middleware/auth';

const users = new Hono();

users.use('*', authMiddleware);

users.get('/', async (c) => {
  const currentUserId = c.get('userId');

  const results = await c.env.DB.prepare(
    `SELECT userId, username
     FROM users
     WHERE userId != ?
     ORDER BY username COLLATE NOCASE ASC`
  )
    .bind(currentUserId)
    .all();

  return c.json({
    users: results.results ?? [],
  });
});

export default users;