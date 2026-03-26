import { Hono } from 'hono';
import { authMiddleware } from '../middleware/auth';

const events = new Hono();

events.use('*', authMiddleware);

// --- POST /events ---
events.post('/', async (c) => {
  const body = await c.req.json();
  const { groupId, eventName } = body;
  const createdBy = c.get('userId');

  if (!groupId || !eventName?.trim()) {
    return c.json({ error: 'groupId and eventName are required' }, 400);
  }

  const result = await c.env.DB.prepare(
    `INSERT INTO events (groupId, eventName, shoppingList, itemList, status, createdBy, createdAt)
     VALUES (?, ?, NULL, NULL, 'open', ?, datetime('now'))`
  )
    .bind(groupId, eventName.trim(), createdBy)
    .run();

  const eventId = Number(result.meta.last_row_id);

  const event = await c.env.DB.prepare(
    'SELECT * FROM events WHERE eventId = ?'
  )
    .bind(eventId)
    .first();

  return c.json({ event }, 201);
});

// --- GET /events/:eventId ---
events.get('/:eventId', async (c) => {
  const eventId = Number(c.req.param('eventId'));

  if (!Number.isInteger(eventId) || eventId <= 0) {
    return c.json({ error: 'Invalid event ID' }, 400);
  }

  const event = await c.env.DB.prepare(
    'SELECT * FROM events WHERE eventId = ?'
  )
    .bind(eventId)
    .first();

  if (!event) {
    return c.json({ error: 'Event not found' }, 404);
  }

  return c.json({
    event: {
      ...event,
      shoppingList: event.shoppingList ? JSON.parse(event.shoppingList) : null,
      itemList: event.itemList ? JSON.parse(event.itemList) : null,
    },
  });
});

// --- PATCH /events/:eventId ---
events.patch('/:eventId', async (c) => {
  const eventId = Number(c.req.param('eventId'));
  const body = await c.req.json();

  if (!Number.isInteger(eventId) || eventId <= 0) {
    return c.json({ error: 'Invalid event ID' }, 400);
  }

  const statements = [];

  if (body.shoppingList !== undefined) {
    statements.push(
      c.env.DB.prepare('UPDATE events SET shoppingList = ? WHERE eventId = ?')
        .bind(JSON.stringify(body.shoppingList), eventId)
    );
  }

  if (body.itemList !== undefined) {
    statements.push(
      c.env.DB.prepare('UPDATE events SET itemList = ? WHERE eventId = ?')
        .bind(JSON.stringify(body.itemList), eventId)
    );
  }

  if (statements.length > 0) {
    await c.env.DB.batch(statements);
  }

  return c.json({ success: true });
});

// --- GET /events/group/:groupId ---
events.get('/group/:groupId', async (c) => {
  const groupId = Number(c.req.param('groupId'));

  if (!Number.isInteger(groupId) || groupId <= 0) {
    return c.json({ error: 'Invalid group ID' }, 400);
  }

  const results = await c.env.DB.prepare(
    'SELECT eventId, groupId, eventName, status, createdBy, createdAt FROM events WHERE groupId = ? ORDER BY createdAt DESC'
  )
    .bind(groupId)
    .all();

  return c.json({ events: results.results ?? [] });
});

// --- GET /groups/:groupId/members ---
events.get('/groups/:groupId/members', async (c) => {
  const groupId = Number(c.req.param('groupId'));

  if (!Number.isInteger(groupId) || groupId <= 0) {
    return c.json({ error: 'Invalid group ID' }, 400);
  }

  const results = await c.env.DB.prepare(
    `SELECT u.userId, u.username, ug.role
     FROM user_groups ug
     INNER JOIN users u ON u.userId = ug.userId
     WHERE ug.groupId = ?
     ORDER BY u.username ASC`
  )
    .bind(groupId)
    .all();

  return c.json({ members: results.results ?? [] });
});

export default events;
