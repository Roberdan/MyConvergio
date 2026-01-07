// Plan, Project, Kanban, and Token Routes
// Combines all plan-related route modules

const routesCore = require('./routes-plans-core');
const routesActions = require('./routes-plans-actions');
const routesMarkdown = require('./routes-plans-markdown');
const routesArchive = require('./routes-plans-archive');

const routes = {
  ...routesCore,
  ...routesActions,
  ...routesMarkdown,
  ...routesArchive
};

module.exports = routes;

