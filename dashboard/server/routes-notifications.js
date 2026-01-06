// Notification Routes

const { query, escapeSQL } = require('./db');

// SSE clients for real-time notifications
const sseClients = new Set();

// Broadcast notification to all SSE clients
function broadcastNotification(notification) {
  const data = JSON.stringify(notification);
  sseClients.forEach(client => {
    try {
      client.write(`event: notification\ndata: ${data}\n\n`);
    } catch (e) {
      sseClients.delete(client);
    }
  });
}

// SSE endpoint handler
function handleSSE(req, res) {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Access-Control-Allow-Origin': '*'
  });

  // Send initial unread count
  const unreadCount = query('SELECT COUNT(*) as count FROM notifications WHERE is_read = 0 AND is_dismissed = 0')[0]?.count || 0;
  res.write(`event: count\ndata: ${JSON.stringify({ count: unreadCount })}\n\n`);

  sseClients.add(res);
  console.log(`Notification SSE client connected (total: ${sseClients.size})`);

  req.on('close', () => {
    sseClients.delete(res);
    console.log(`Notification SSE client disconnected (remaining: ${sseClients.size})`);
  });

  // Keep-alive ping every 30s
  const pingInterval = setInterval(() => {
    try {
      res.write(': ping\n\n');
    } catch (e) {
      clearInterval(pingInterval);
      sseClients.delete(res);
    }
  }, 30000);

  req.on('close', () => clearInterval(pingInterval));
}

const routes = {
  // Get all notifications (with optional filters)
  'GET /api/notifications': (params, body, url) => {
    let whereClause = '1=1';
    const searchParams = url?.searchParams || new URLSearchParams();

    const projectId = searchParams.get('project');
    const unreadOnly = searchParams.get('unread') === 'true';
    const severity = searchParams.get('severity');
    const limit = parseInt(searchParams.get('limit')) || 100;
    const offset = parseInt(searchParams.get('offset')) || 0;
    const search = searchParams.get('search');

    if (projectId) whereClause += ` AND n.project_id = '${escapeSQL(projectId)}'`;
    if (unreadOnly) whereClause += ' AND n.is_read = 0 AND n.is_dismissed = 0';
    if (severity) whereClause += ` AND n.severity = '${escapeSQL(severity)}'`;
    if (search) whereClause += ` AND (n.title LIKE '%${escapeSQL(search)}%' OR n.message LIKE '%${escapeSQL(search)}%')`;

    const notifications = query(`
      SELECT n.*, p.name as project_name
      FROM notifications n
      JOIN projects p ON n.project_id = p.id
      WHERE ${whereClause}
      ORDER BY n.created_at DESC
      LIMIT ${limit} OFFSET ${offset}
    `);

    const total = query(`SELECT COUNT(*) as count FROM notifications n WHERE ${whereClause}`)[0]?.count || 0;

    return { notifications, total, limit, offset };
  },

  // Get unread notifications count and recent
  'GET /api/notifications/unread': () => {
    const unread = query(`
      SELECT n.*, p.name as project_name
      FROM notifications n
      JOIN projects p ON n.project_id = p.id
      WHERE n.is_read = 0 AND n.is_dismissed = 0
      ORDER BY n.created_at DESC
      LIMIT 20
    `);

    const countByProject = query(`
      SELECT project_id, COUNT(*) as count
      FROM notifications
      WHERE is_read = 0 AND is_dismissed = 0
      GROUP BY project_id
    `);

    const countBySeverity = query(`
      SELECT severity, COUNT(*) as count
      FROM notifications
      WHERE is_read = 0 AND is_dismissed = 0
      GROUP BY severity
    `);

    return {
      notifications: unread,
      total: unread.length,
      byProject: countByProject,
      bySeverity: countBySeverity
    };
  },

  // Create a notification
  'POST /api/notifications': (params, body) => {
    const { project_id, type, severity, title, message, link, link_type, source_table, source_id } = body;

    if (!project_id || !type || !title) {
      return { error: 'Missing required fields: project_id, type, title' };
    }

    query(`
      INSERT INTO notifications (project_id, type, severity, title, message, link, link_type, source_table, source_id)
      VALUES ('${escapeSQL(project_id)}', '${escapeSQL(type)}', '${escapeSQL(severity || 'info')}', '${escapeSQL(title)}',
              '${escapeSQL(message || '')}', '${escapeSQL(link || '')}', '${escapeSQL(link_type || '')}',
              '${escapeSQL(source_table || '')}', '${escapeSQL(source_id || '')}')
    `);

    const notification = query(`
      SELECT n.*, p.name as project_name
      FROM notifications n
      JOIN projects p ON n.project_id = p.id
      ORDER BY n.id DESC LIMIT 1
    `)[0];

    // Broadcast to SSE clients
    broadcastNotification(notification);

    return { success: true, notification };
  },

  // Mark notification as read
  'POST /api/notifications/:id/read': (params) => {
    const id = parseInt(params.id);
    if (isNaN(id)) return { error: 'Invalid notification ID' };
    query(`UPDATE notifications SET is_read = 1, read_at = CURRENT_TIMESTAMP WHERE id = ${id}`);
    return { success: true, id };
  },

  // Dismiss notification
  'POST /api/notifications/:id/dismiss': (params) => {
    const id = parseInt(params.id);
    if (isNaN(id)) return { error: 'Invalid notification ID' };
    query(`UPDATE notifications SET is_dismissed = 1 WHERE id = ${id}`);
    return { success: true, id };
  },

  // Mark all as read (optionally for a project)
  'POST /api/notifications/read-all': (params, body) => {
    const projectClause = body.project_id ? `AND project_id = '${escapeSQL(body.project_id)}'` : '';
    query(`UPDATE notifications SET is_read = 1, read_at = CURRENT_TIMESTAMP WHERE is_read = 0 ${projectClause}`);
    return { success: true };
  },

  // Get notification triggers configuration
  'GET /api/notifications/triggers': () => {
    return query('SELECT * FROM notification_triggers ORDER BY event_type');
  },

  // Toggle notification trigger
  'POST /api/notifications/triggers/:id/toggle': (params) => {
    const id = parseInt(params.id);
    if (isNaN(id)) return { error: 'Invalid trigger ID' };
    query(`UPDATE notification_triggers SET is_enabled = 1 - is_enabled WHERE id = ${id}`);
    return { success: true };
  },

  // Delete notification
  'DELETE /api/notifications/:id': (params) => {
    const id = parseInt(params.id);
    if (isNaN(id)) return { error: 'Invalid notification ID' };
    query(`DELETE FROM notifications WHERE id = ${id}`);
    return { success: true, id };
  },

  // Clear all notifications (optionally for a project)
  'DELETE /api/notifications': (params, body) => {
    const projectClause = body?.project_id ? `WHERE project_id = '${escapeSQL(body.project_id)}'` : '';
    const result = query(`SELECT COUNT(*) as count FROM notifications ${projectClause}`);
    const count = result[0]?.count || 0;
    query(`DELETE FROM notifications ${projectClause}`);
    return { success: true, cleared: count };
  },

  // Handle notification action
  'POST /api/notifications/:id/action': (params, body) => {
    const id = parseInt(params.id);
    const { action } = body;
    
    if (isNaN(id)) return { error: 'Invalid notification ID' };
    if (!action) return { error: 'Action required' };
    
    const notification = query(`SELECT * FROM notifications WHERE id = ${id}`)[0];
    if (!notification) return { error: 'Notification not found' };
    
    // Handle different actions
    let result = { success: true, message: 'Action completed' };
    
    try {
      switch (action) {
        case 'view_plan':
          result.message = 'Opening plan...';
          result.redirect = `/plan/${notification.source_id}`;
          break;
          
        case 'view_task':
          result.message = 'Opening task...';
          result.redirect = `/task/${notification.source_id}`;
          break;
          
        case 'view_commit':
          result.message = 'Opening commit...';
          result.redirect = `/commit/${notification.source_id}`;
          break;
          
        case 'dismiss':
          query(`UPDATE notifications SET is_dismissed = 1 WHERE id = ${id}`);
          result.message = 'Notification dismissed';
          break;
          
        default:
          result.message = `Action '${action}' executed`;
      }
      
      // Mark as read after action
      query(`UPDATE notifications SET is_read = 1, read_at = CURRENT_TIMESTAMP WHERE id = ${id}`);
      
      return result;
    } catch (err) {
      return { success: false, error: err.message };
    }
  }
};

module.exports = { routes, handleSSE, broadcastNotification };
