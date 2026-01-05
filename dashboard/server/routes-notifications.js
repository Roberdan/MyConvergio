// Notification Routes

const { query } = require('./db');

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

    if (projectId) whereClause += ` AND n.project_id = '${projectId}'`;
    if (unreadOnly) whereClause += ' AND n.is_read = 0 AND n.is_dismissed = 0';
    if (severity) whereClause += ` AND n.severity = '${severity}'`;
    if (search) whereClause += ` AND (n.title LIKE '%${search}%' OR n.message LIKE '%${search}%')`;

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
      VALUES ('${project_id}', '${type}', '${severity || 'info'}', '${title.replace(/'/g, "''")}',
              '${(message || '').replace(/'/g, "''")}', '${link || ''}', '${link_type || ''}',
              '${source_table || ''}', '${source_id || ''}')
    `);

    const notification = query('SELECT * FROM notifications ORDER BY id DESC LIMIT 1')[0];
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
    query(`UPDATE notifications SET is_dismissed = 1 WHERE id = ${params.id}`);
    return { success: true, id: params.id };
  },

  // Mark all as read (optionally for a project)
  'POST /api/notifications/read-all': (params, body) => {
    const projectClause = body.project_id ? `AND project_id = '${body.project_id}'` : '';
    query(`UPDATE notifications SET is_read = 1, read_at = CURRENT_TIMESTAMP WHERE is_read = 0 ${projectClause}`);
    return { success: true };
  },

  // Get notification triggers configuration
  'GET /api/notifications/triggers': () => {
    return query('SELECT * FROM notification_triggers ORDER BY event_type');
  },

  // Toggle notification trigger
  'POST /api/notifications/triggers/:id/toggle': (params) => {
    query(`UPDATE notification_triggers SET is_enabled = 1 - is_enabled WHERE id = ${params.id}`);
    return { success: true };
  }
};

module.exports = routes;
