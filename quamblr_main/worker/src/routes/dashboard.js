import { Hono } from 'hono';
import { authMiddleware } from '../middleware/auth'; // Ensure this path matches your setup

const dashboard = new Hono();

// Protect all dashboard routes
dashboard.use('*', authMiddleware);

dashboard.get('/', async (c) => {
  const userId = c.get('userId');

  // 1. Calculate how much the user is OWED
  // (They paid for an expense, and others haven't settled yet)
  const owedResult = await c.env.DB.prepare(
    `
    SELECT SUM(es.amountOwed) as totalOwed
    FROM expense_splits es
    INNER JOIN expenses e ON e.expenseId = es.expenseId
    WHERE e.paidBy = ? AND es.userId != ? AND es.isSettled = 0
  `,
  )
    .bind(userId, userId)
    .first();

  // 2. Calculate how much the user OWES
  // (They are in the split for an expense someone else paid, and haven't settled)
  const oweResult = await c.env.DB.prepare(
    `
    SELECT SUM(amountOwed) as totalOwe
    FROM expense_splits
    WHERE userId = ? AND isSettled = 0
  `,
  )
    .bind(userId)
    .first();

  // 3. Fetch Personal Lists
  const listsResult = await c.env.DB.prepare(
    `
    SELECT listId, title, icon 
    FROM personal_lists 
    WHERE userId = ? 
    ORDER BY createdAt DESC 
    LIMIT 5
  `,
  )
    .bind(userId)
    .all();

  // 4. Fetch Personal Activities (that are not done)
  const activitiesResult = await c.env.DB.prepare(
    `
    SELECT activityId, title, icon 
    FROM personal_activities 
    WHERE userId = ? AND isDone = 0 
    ORDER BY createdAt DESC 
    LIMIT 5
  `,
  )
    .bind(userId)
    .all();

  // 5. Fetch Recent Activity (Merge of latest expenses and events)
  // We use a UNION to combine them into a single timeline feed
  const recentResult = await c.env.DB.prepare(
    `
    SELECT 'expense' as type, title, amount as meta, createdAt
    FROM expenses 
    WHERE paidBy = ? OR groupId IN (SELECT groupId FROM user_groups WHERE userId = ?)
    
    UNION ALL
    
    SELECT 'event' as type, eventName as title, status as meta, createdAt
    FROM events
    WHERE createdBy = ? OR groupId IN (SELECT groupId FROM user_groups WHERE userId = ?)
    
    ORDER BY createdAt DESC
    LIMIT 5
  `,
  )
    .bind(userId, userId, userId, userId)
    .all();

  // Construct and return the final JSON payload
  return c.json({
    financial: {
      owed: owedResult.totalOwed ?? 0,
      owe: oweResult.totalOwe ?? 0,
    },
    lists: listsResult.results ?? [],
    activities: activitiesResult.results ?? [],
    recent: recentResult.results ?? [],
  });
});

export default dashboard;
