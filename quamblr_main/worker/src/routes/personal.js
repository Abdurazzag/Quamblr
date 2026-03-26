import { Hono } from 'hono';
import { authMiddleware } from '../middleware/auth';

const personal = new Hono();

personal.use('*', authMiddleware);

// --- ACTIVITIES ---
personal.post('/activities', async (c) => {
  const userId = c.get('userId');
  const { title } = await c.req.json();

  if (!title) return c.json({ error: 'Title is required' }, 400);

  await c.env.DB.prepare(
    `INSERT INTO personal_activities (userId, title, icon, isDone, createdAt) VALUES (?, ?, 'task_alt', 0, datetime('now'))`,
  )
    .bind(userId, title)
    .run();

  return c.json({ message: 'Activity added' }, 201);
});

personal.delete('/activities/:id', async (c) => {
  const userId = c.get('userId');
  const activityId = c.req.param('id');

  await c.env.DB.prepare(
    `DELETE FROM personal_activities WHERE activityId = ? AND userId = ?`,
  )
    .bind(activityId, userId)
    .run();

  return c.json({ message: 'Activity removed' });
});

// --- LISTS ---
personal.post('/lists', async (c) => {
  const userId = c.get('userId');
  const { title } = await c.req.json();

  if (!title) return c.json({ error: 'Title is required' }, 400);

  await c.env.DB.prepare(
    `INSERT INTO personal_lists (userId, title, icon, createdAt) VALUES (?, ?, 'list_alt', datetime('now'))`,
  )
    .bind(userId, title)
    .run();

  return c.json({ message: 'List added' }, 201);
});

personal.delete('/lists/:id', async (c) => {
  const userId = c.get('userId');
  const listId = c.req.param('id');

  await c.env.DB.prepare(
    `DELETE FROM personal_lists WHERE listId = ? AND userId = ?`,
  )
    .bind(listId, userId)
    .run();

  return c.json({ message: 'List removed' });
});

// --- SPECIFIC LIST ITEMS ---

// 1. Get all items in a specific list
personal.get('/lists/:listId/items', async (c) => {
  const userId = c.get('userId');
  const listId = c.req.param('listId');

  // Verify the user actually owns this list
  const list = await c.env.DB.prepare(
    'SELECT listId FROM personal_lists WHERE listId = ? AND userId = ?',
  )
    .bind(listId, userId)
    .first();

  if (!list) return c.json({ error: 'List not found or unauthorized' }, 403);

  const items = await c.env.DB.prepare(
    'SELECT * FROM personal_list_items WHERE listId = ? ORDER BY isDone ASC, createdAt DESC',
  )
    .bind(listId)
    .all();

  return c.json({ items: items.results ?? [] });
});

// 2. Add a new item to a list
personal.post('/lists/:listId/items', async (c) => {
  const listId = c.req.param('listId');
  const { content, quantity, price } = await c.req.json();

  if (!content) return c.json({ error: 'Item name is required' }, 400);

  await c.env.DB.prepare(
    `INSERT INTO personal_list_items (listId, content, quantity, price, isDone, createdAt) 
     VALUES (?, ?, ?, ?, 0, datetime('now'))`,
  )
    .bind(listId, content, quantity ?? 1, price ?? 0.0)
    .run();

  return c.json({ message: 'Item added' }, 201);
});

// 3. Toggle checkbox status
personal.patch('/lists/items/:itemId', async (c) => {
  const itemId = c.req.param('itemId');
  const { isDone } = await c.req.json();

  await c.env.DB.prepare(
    'UPDATE personal_list_items SET isDone = ? WHERE itemId = ?',
  )
    .bind(isDone ? 1 : 0, itemId)
    .run();

  return c.json({ message: 'Item updated' });
});

// 4. Delete an item
personal.delete('/lists/items/:itemId', async (c) => {
  const itemId = c.req.param('itemId');
  await c.env.DB.prepare('DELETE FROM personal_list_items WHERE itemId = ?')
    .bind(itemId)
    .run();
  return c.json({ message: 'Item deleted' });
});

export default personal;
