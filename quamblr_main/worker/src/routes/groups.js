import { Hono } from 'hono';
import { authMiddleware } from '../middleware/auth';

const groups = new Hono();

groups.use('*', authMiddleware);

groups.get('/', async (c) => {
  const userId = c.get('userId');

  const results = await c.env.DB.prepare(
    `SELECT
       g.groupId,
       g.groupName,
       g.frequentItems,
       g.favouriteItems,
       g.groupChores,
       g.createdAt,
       ug.role,
       ug.joinedAt
     FROM groups g
     INNER JOIN user_groups ug ON ug.groupId = g.groupId
     WHERE ug.userId = ?
     ORDER BY g.createdAt DESC`,
  )
    .bind(userId)
    .all();

  return c.json({
    groups: results.results ?? [],
  });
});

groups.post('/', async (c) => {
  const body = await c.req.json();
  const groupName = body.groupName?.trim();
  const userId = c.get('userId');

  const rawMemberUserIds = body.memberUserIds;
  const memberUserIds =
    rawMemberUserIds instanceof Array
      ? [
          ...new Set(
            rawMemberUserIds
              .filter((value) => Number.isInteger(value) && Number(value) > 0)
              .map((value) => Number(value)),
          ),
        ]
      : [];

  if (!groupName) {
    return c.json({ error: 'Group name is required' }, 400);
  }

  if (groupName.length < 3) {
    return c.json({ error: 'Group name must be at least 3 characters' }, 400);
  }

  const createResult = await c.env.DB.prepare(
    `INSERT INTO groups (
      groupName,
      frequentItems,
      favouriteItems,
      groupChores,
      createdAt
    ) VALUES (?, ?, ?, ?, datetime('now'))`,
  )
    .bind(groupName, '[]', '[]', '[]')
    .run();

  const groupId = Number(createResult.meta.last_row_id);

  const validMemberIds = [];
  const filteredMemberIds = memberUserIds.filter(
    (memberId) => Number(memberId) !== Number(userId),
  );

  if (filteredMemberIds.length > 0) {
    const placeholders = filteredMemberIds.map(() => '?').join(', ');
    const existingUsers = await c.env.DB.prepare(
      `SELECT userId
       FROM users
       WHERE userId IN (${placeholders})`,
    )
      .bind(...filteredMemberIds)
      .all();

    for (const row of existingUsers.results ?? []) {
      const existingUserId = Number(row.userId);
      if (Number.isInteger(existingUserId)) {
        validMemberIds.push(existingUserId);
      }
    }
  }

  const membershipStatements = [
    c.env.DB.prepare(
      `INSERT INTO user_groups (userId, groupId, role, joinedAt)
       VALUES (?, ?, ?, datetime('now'))`,
    ).bind(userId, groupId, 'owner'),
    ...validMemberIds.map((memberId) =>
      c.env.DB.prepare(
        `INSERT INTO user_groups (userId, groupId, role, joinedAt)
         VALUES (?, ?, ?, datetime('now'))`,
      ).bind(memberId, groupId, 'member'),
    ),
  ];

  await c.env.DB.batch(membershipStatements);

  const group = await c.env.DB.prepare(
    `SELECT groupId, groupName, frequentItems, favouriteItems, groupChores, createdAt
     FROM groups
     WHERE groupId = ?`,
  )
    .bind(groupId)
    .first();

  return c.json(
    {
      message: 'Group created successfully',
      group,
    },
    201,
  );
});

groups.get('/:groupId/members', async (c) => {
  const userId = c.get('userId');
  const groupId = Number(c.req.param('groupId'));

  if (!Number.isInteger(groupId) || groupId <= 0) {
    return c.json({ error: 'Invalid group ID' }, 400);
  }

  const membership = await c.env.DB.prepare(
    `SELECT 1
     FROM user_groups
     WHERE userId = ? AND groupId = ?`,
  )
    .bind(userId, groupId)
    .first();

  if (!membership) {
    return c.json({ error: 'Group not found' }, 404);
  }

  const results = await c.env.DB.prepare(
    `SELECT
       u.userId,
       u.username,
       ug.role,
       ug.joinedAt
     FROM user_groups ug
     INNER JOIN users u ON u.userId = ug.userId
     WHERE ug.groupId = ?
     ORDER BY
       CASE WHEN ug.role = 'owner' THEN 0 ELSE 1 END,
       u.username COLLATE NOCASE ASC`,
  )
    .bind(groupId)
    .all();

  return c.json({
    members: results.results ?? [],
  });
});

groups.delete('/:groupId', async (c) => {
  const userId = c.get('userId');
  const groupId = Number(c.req.param('groupId'));

  if (!Number.isInteger(groupId) || groupId <= 0) {
    return c.json({ error: 'Invalid group ID' }, 400);
  }

  const membership = await c.env.DB.prepare(
    `SELECT role
     FROM user_groups
     WHERE userId = ? AND groupId = ?`,
  )
    .bind(userId, groupId)
    .first();

  if (!membership) {
    return c.json({ error: 'Group not found' }, 404);
  }

  if (membership.role !== 'owner') {
    return c.json({ error: 'Only the group owner can delete this group' }, 403);
  }

  await c.env.DB.batch([
    c.env.DB.prepare('DELETE FROM events WHERE groupId = ?').bind(groupId),
    c.env.DB.prepare('DELETE FROM user_groups WHERE groupId = ?').bind(groupId),
    c.env.DB.prepare('DELETE FROM groups WHERE groupId = ?').bind(groupId),
  ]);

  return c.json({
    message: 'Group deleted successfully',
  });
});

// --- GROUP LISTS ---

// Get all lists for a group
groups.get('/:groupId/lists', async (c) => {
  const groupId = c.req.param('groupId');
  const lists = await c.env.DB.prepare(
    'SELECT * FROM group_lists WHERE groupId = ? ORDER BY createdAt DESC',
  )
    .bind(groupId)
    .all();
  return c.json({ lists: lists.results ?? [] });
});

// Add a list to a group
groups.post('/:groupId/lists', async (c) => {
  const groupId = c.req.param('groupId');
  const userId = c.get('userId');
  const { title } = await c.req.json();

  if (!title) return c.json({ error: 'Title is required' }, 400);

  await c.env.DB.prepare(
    `INSERT INTO group_lists (groupId, title, createdBy, createdAt) VALUES (?, ?, ?, datetime('now'))`,
  )
    .bind(groupId, title, userId)
    .run();

  return c.json({ message: 'Group list added' }, 201);
});

// Delete a group list
groups.delete('/lists/:listId', async (c) => {
  const listId = c.req.param('listId');
  await c.env.DB.prepare('DELETE FROM group_lists WHERE listId = ?')
    .bind(listId)
    .run();
  return c.json({ message: 'Group list deleted' });
});

// --- GROUP LIST ITEMS ---

groups.get('/lists/:listId/items', async (c) => {
  const listId = c.req.param('listId');

  // Fetch items along with purchaser name and a JSON array of claimers
  const items = await c.env.DB.prepare(
    `
    SELECT i.*, 
           u.username as purchaserName,
           (SELECT json_group_array(json_object('userId', c.userId, 'username', cu.username))
            FROM group_item_claims c 
            JOIN users cu ON c.userId = cu.userId 
            WHERE c.itemId = i.itemId) as claimersJson
    FROM group_list_items i
    LEFT JOIN users u ON i.purchasedBy = u.userId
    WHERE i.listId = ?
    ORDER BY i.isDone ASC, i.createdAt DESC
  `,
  )
    .bind(listId)
    .all();

  // Parse the SQLite JSON string into actual Javascript arrays
  const formattedItems = (items.results ?? []).map((item) => {
    const parsedClaimers = item.claimersJson
      ? JSON.parse(item.claimersJson)
      : [];
    // SQLite json_group_array might return [null] if empty, so we filter it
    const validClaimers = parsedClaimers.filter((c) => c.userId !== null);
    return { ...item, claimers: validClaimers };
  });

  return c.json({ items: formattedItems });
});

groups.post('/lists/:listId/items', async (c) => {
  const listId = c.req.param('listId');
  const userId = c.get('userId');
  const { content, quantity, price } = await c.req.json();

  if (!content) return c.json({ error: 'Item name is required' }, 400);

  // 1. Insert the item
  const res = await c.env.DB.prepare(
    `
    INSERT INTO group_list_items (listId, content, quantity, price, isDone, addedBy, createdAt) 
    VALUES (?, ?, ?, ?, 0, ?, datetime('now'))
  `,
  )
    .bind(listId, content, quantity ?? 1, price ?? 0.0, userId)
    .run();

  const newItemId = res.meta.last_row_id;

  // 2. Automatically add the creator as the first claimer
  await c.env.DB.prepare(
    `
    INSERT INTO group_item_claims (itemId, userId) VALUES (?, ?)
  `,
  )
    .bind(newItemId, userId)
    .run();

  return c.json({ message: 'Item added and claimed' }, 201);
});

// Toggle a claim on an item
groups.post('/lists/items/:itemId/claim', async (c) => {
  const itemId = c.req.param('itemId');
  const userId = c.get('userId');

  const existing = await c.env.DB.prepare(
    'SELECT 1 FROM group_item_claims WHERE itemId = ? AND userId = ?',
  )
    .bind(itemId, userId)
    .first();

  if (existing) {
    await c.env.DB.prepare(
      'DELETE FROM group_item_claims WHERE itemId = ? AND userId = ?',
    )
      .bind(itemId, userId)
      .run();
    return c.json({ message: 'Claim removed' });
  } else {
    await c.env.DB.prepare(
      'INSERT INTO group_item_claims (itemId, userId) VALUES (?, ?)',
    )
      .bind(itemId, userId)
      .run();
    return c.json({ message: 'Claim added' });
  }
});

// The Purchase Engine - Integrates directly with your financial tables!
groups.post('/lists/items/:itemId/purchase', async (c) => {
  const itemId = c.req.param('itemId');
  const userId = c.get('userId');

  // Fetch the item details and which group it belongs to
  const item = await c.env.DB.prepare(
    `
    SELECT i.*, l.groupId 
    FROM group_list_items i
    JOIN group_lists l ON i.listId = l.listId
    WHERE i.itemId = ?
  `,
  )
    .bind(itemId)
    .first();

  if (!item) return c.json({ error: 'Item not found' }, 404);
  if (item.isDone) return c.json({ error: 'Already purchased' }, 400);

  // Find out who claimed it
  const claimersRes = await c.env.DB.prepare(
    'SELECT userId FROM group_item_claims WHERE itemId = ?',
  )
    .bind(itemId)
    .all();
  const claimerIds = claimersRes.results.map((r) => r.userId);

  // If no one claimed it, default the purchaser to being the sole claimer
  if (claimerIds.length === 0) claimerIds.push(userId);

  const totalCost = item.price * item.quantity;
  const splitAmount = totalCost / claimerIds.length;

  // 1. Mark item as purchased
  await c.env.DB.prepare(
    'UPDATE group_list_items SET isDone = 1, purchasedBy = ? WHERE itemId = ?',
  )
    .bind(userId, itemId)
    .run();

  if (totalCost > 0) {
    // 2. Insert into expenses
    const expenseRes = await c.env.DB.prepare(
      `
      INSERT INTO expenses (groupId, paidBy, title, amount, createdAt)
      VALUES (?, ?, ?, ?, datetime('now'))
    `,
    )
      .bind(item.groupId, userId, `Bought: ${item.content}`, totalCost)
      .run();

    const expenseId = expenseRes.meta.last_row_id;

    // 3. Create splits for who owes who
    for (const cid of claimerIds) {
      const isSettled = cid === userId ? 1 : 0; // Purchaser doesn't owe themselves
      await c.env.DB.prepare(
        `
        INSERT INTO expense_splits (expenseId, userId, amountOwed, isSettled)
        VALUES (?, ?, ?, ?)
      `,
      )
        .bind(expenseId, cid, splitAmount, isSettled)
        .run();
    }
  }

  return c.json({ message: 'Item purchased and expenses calculated!' });
});

groups.delete('/lists/items/:itemId', async (c) => {
  const itemId = c.req.param('itemId');
  await c.env.DB.prepare('DELETE FROM group_list_items WHERE itemId = ?')
    .bind(itemId)
    .run();
  return c.json({ message: 'Item deleted' });
});

export default groups;
