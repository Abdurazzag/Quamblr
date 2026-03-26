import { Hono } from 'hono';
import { cors } from 'hono/cors';
import auth from './routes/auth';
import groups from './routes/groups.js';
import users from './routes/users.js';
import events from './routes/events.js';
import dashboard from './routes/dashboard.js';
import personal from './routes/personal.js';

const app = new Hono();

app.use('*', cors());
app.route('/auth', auth);
app.route('/groups', groups);
app.route('/users', users);
app.route('/events', events);
app.route('/dashboard', dashboard);
app.route('/personal', personal);

app.get('/', (c) => c.json({ message: 'Quamblr API' }));

export default {
  fetch: app.fetch,
};
