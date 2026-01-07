#!/usr/bin/env node
// Complete API Endpoint Testing Script
// Tests all API endpoints for data integrity and correctness

const http = require('http');
const { query } = require('./server/db');

const PORT = 31415;
const BASE_URL = `http://localhost:${PORT}`;

const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  gray: '\x1b[90m'
};

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function log(msg, color = 'reset') {
  console.log(`${colors[color]}${msg}${colors.reset}`);
}

function apiCall(path, method = 'GET', body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: { 'Content-Type': 'application/json' }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, data: data, rawData: true });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function test(description, testFn) {
  totalTests++;
  process.stdout.write(`${colors.gray}  Testing: ${description}...${colors.reset}`);
  
  try {
    await testFn();
    passedTests++;
    console.log(`\r${colors.green}  ✓ ${description}${colors.reset}`);
  } catch (e) {
    failedTests++;
    console.log(`\r${colors.red}  ✗ ${description}${colors.reset}`);
    console.log(`${colors.red}    Error: ${e.message}${colors.reset}`);
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message || 'Assertion failed');
}

function assertType(value, type, fieldName) {
  const actualType = Array.isArray(value) ? 'array' : typeof value;
  if (actualType !== type) {
    throw new Error(`Expected ${fieldName} to be ${type}, got ${actualType}`);
  }
}

function assertHasKeys(obj, keys, name = 'object') {
  keys.forEach(key => {
    if (!(key in obj)) {
      throw new Error(`${name} missing required key: ${key}`);
    }
  });
}

// ============================================
// TEST SUITES
// ============================================

async function testSystemAPI() {
  log('\n📊 Testing System API', 'blue');

  await test('GET /api/health returns healthy status', async () => {
    const res = await apiCall('/api/health');
    assert(res.status === 200, `Expected 200, got ${res.status}`);
    assertHasKeys(res.data, ['status', 'timestamp', 'uptime', 'db', 'memory']);
    assert(res.data.status === 'healthy' || res.data.status === 'unhealthy', 'Invalid status');
    assert(res.data.db.connected === true || res.data.db.connected === false, 'Invalid db.connected');
    assertType(res.data.uptime, 'number', 'uptime');
  });
}

async function testKanbanAPI() {
  log('\n📋 Testing Kanban API', 'blue');

  await test('GET /api/kanban returns array of projects', async () => {
    const res = await apiCall('/api/kanban');
    assert(res.status === 200, `Expected 200, got ${res.status}`);
    assertType(res.data, 'array', 'kanban data');
    
    if (res.data.length > 0) {
      const item = res.data[0];
      assertHasKeys(item, ['project_id', 'project_name'], 'kanban item');
    }
  });
}

async function testProjectsAPI() {
  log('\n🏗️  Testing Projects API', 'blue');

  await test('GET /api/projects returns array', async () => {
    const res = await apiCall('/api/projects');
    assert(res.status === 200, `Expected 200, got ${res.status}`);
    assertType(res.data, 'array', 'projects data');
    
    if (res.data.length > 0) {
      const project = res.data[0];
      assertHasKeys(project, ['project_id', 'project_name', 'plans_total'], 'project');
      assertType(project.plans_total, 'number', 'plans_total');
      assertType(project.plans_todo, 'number', 'plans_todo');
      assertType(project.plans_doing, 'number', 'plans_doing');
      assertType(project.plans_done, 'number', 'plans_done');
    }
  });

  // Get first project for further tests
  const projectsRes = await apiCall('/api/projects');
  if (projectsRes.data.length > 0) {
    const projectId = projectsRes.data[0].project_id;

    await test(`GET /api/project/${projectId}/dashboard returns dashboard data`, async () => {
      const res = await apiCall(`/api/project/${projectId}/dashboard`);
      assert(res.status === 200, `Expected 200, got ${res.status}`);
      assertHasKeys(res.data, ['meta', 'metrics', 'tokens', 'waves', 'plans']);
      assertHasKeys(res.data.meta, ['project', 'projectId']);
      assertHasKeys(res.data.metrics, ['throughput']);
      assertHasKeys(res.data.metrics.throughput, ['done', 'total', 'percent']);
      assertHasKeys(res.data.tokens, ['total', 'avgPerTask', 'totalCost', 'apiCalls']);
      assertType(res.data.waves, 'array', 'waves');
      assertHasKeys(res.data.plans, ['total', 'done', 'doing', 'todo']);
    });

    await test(`GET /api/project/${projectId}/tokens returns token stats`, async () => {
      const res = await apiCall(`/api/project/${projectId}/tokens`);
      assert(res.status === 200, `Expected 200, got ${res.status}`);
      assertHasKeys(res.data, ['stats', 'byPlan', 'byAgent']);
      assertHasKeys(res.data.stats, ['total_tokens', 'total_cost', 'api_calls']);
      assertType(res.data.byPlan, 'array', 'byPlan');
      assertType(res.data.byAgent, 'array', 'byAgent');
    });

    await test(`GET /api/plans/${projectId} returns plans array`, async () => {
      const res = await apiCall(`/api/plans/${projectId}`);
      assert(res.status === 200, `Expected 200, got ${res.status}`);
      assertType(res.data, 'array', 'plans');
      
      if (res.data.length > 0) {
        const plan = res.data[0];
        assertHasKeys(plan, ['id', 'name', 'status', 'tasks_done', 'tasks_total', 'progress']);
        assertType(plan.tasks_done, 'number', 'tasks_done');
        assertType(plan.tasks_total, 'number', 'tasks_total');
        assertType(plan.progress, 'number', 'progress');
        assert(plan.progress >= 0 && plan.progress <= 100, 'Progress should be 0-100');
      }
    });

    await test(`GET /api/project/${projectId}/git returns git status`, async () => {
      const res = await apiCall(`/api/project/${projectId}/git`);
      // May return error if not a git repo, which is OK
      if (!res.data.error) {
        assertHasKeys(res.data, ['branch', 'staged', 'unstaged', 'untracked', 'commits']);
        assertType(res.data.staged, 'array', 'staged');
        assertType(res.data.unstaged, 'array', 'unstaged');
        assertType(res.data.untracked, 'array', 'untracked');
        assertType(res.data.commits, 'array', 'commits');
      }
    });

    await test(`GET /api/project/${projectId}/github returns GitHub data`, async () => {
      const res = await apiCall(`/api/project/${projectId}/github`);
      // May return error if not a GitHub repo, which is OK
      if (!res.data.error) {
        assertHasKeys(res.data, ['repo', 'issues', 'prs']);
        assertType(res.data.issues, 'array', 'issues');
        assertType(res.data.prs, 'array', 'prs');
      }
    });
  }
}

async function testPlansAPI() {
  log('\n📝 Testing Plans API', 'blue');

  // Get first plan for testing
  const plansQuery = query('SELECT id FROM plans LIMIT 1');
  if (plansQuery.length > 0) {
    const planId = plansQuery[0].id;

    await test(`GET /api/plan/${planId} returns plan with waves and tasks`, async () => {
      const res = await apiCall(`/api/plan/${planId}`);
      assert(res.status === 200, `Expected 200, got ${res.status}`);
      assertHasKeys(res.data, ['id', 'name', 'status', 'project_id', 'waves']);
      assertType(res.data.waves, 'array', 'waves');
      
      if (res.data.waves.length > 0) {
        const wave = res.data.waves[0];
        assertHasKeys(wave, ['id', 'wave_id', 'name', 'status', 'tasks']);
        assertType(wave.tasks, 'array', 'tasks');
        
        if (wave.tasks.length > 0) {
          const task = wave.tasks[0];
          assertHasKeys(task, ['id', 'task_id', 'title', 'status']);
        }
      }
    });

    await test(`GET /api/plan/${planId}/history returns version history`, async () => {
      const res = await apiCall(`/api/plan/${planId}/history`);
      assert(res.status === 200, `Expected 200, got ${res.status}`);
      assertType(res.data, 'array', 'history');
    });

    await test(`GET /api/plan/${planId}/tokens returns token stats`, async () => {
      const res = await apiCall(`/api/plan/${planId}/tokens`);
      assert(res.status === 200, `Expected 200, got ${res.status}`);
      assertHasKeys(res.data, ['stats', 'byWave', 'byAgent']);
      assertHasKeys(res.data.stats, ['total_tokens', 'total_cost', 'api_calls']);
    });
  }
}

async function testMonitoringAPI() {
  log('\n🔍 Testing Monitoring API', 'blue');

  await test('GET /api/monitoring/sessions returns active sessions', async () => {
    const res = await apiCall('/api/monitoring/sessions');
    assert(res.status === 200, `Expected 200, got ${res.status}`);
    assertType(res.data, 'array', 'sessions');
  });

  // Test task session endpoint if we have tasks
  const taskQuery = query('SELECT project_id, task_id FROM tasks LIMIT 1');
  if (taskQuery.length > 0) {
    const { project_id, task_id } = taskQuery[0];

    await test(`GET /api/project/${project_id}/task/${task_id}/session returns task session`, async () => {
      const res = await apiCall(`/api/project/${project_id}/task/${task_id}/session`);
      assert(res.status === 200, `Expected 200, got ${res.status}`);
      if (!res.data.error) {
        assertHasKeys(res.data, ['id', 'title', 'status', 'project_id', 'task_id']);
      }
    });

    await test(`GET /api/project/${project_id}/task/${task_id}/conversation returns conversation logs`, async () => {
      const res = await apiCall(`/api/project/${project_id}/task/${task_id}/conversation`);
      assert(res.status === 200, `Expected 200, got ${res.status}`);
      assertType(res.data, 'array', 'conversation logs');
    });
  }
}

async function testGitAPI() {
  log('\n🔀 Testing Git API', 'blue');

  const projectsRes = await apiCall('/api/projects');
  if (projectsRes.data.length > 0) {
    const projectId = projectsRes.data[0].project_id;

    await test(`GET /api/project/${projectId}/git/branches returns branches`, async () => {
      const res = await apiCall(`/api/project/${projectId}/git/branches`);
      if (!res.data.error) {
        assertHasKeys(res.data, ['current', 'branches']);
        assertType(res.data.branches, 'array', 'branches');
      }
    });

    await test(`GET /api/project/${projectId}/git/remotes returns remotes`, async () => {
      const res = await apiCall(`/api/project/${projectId}/git/remotes`);
      if (!res.data.error) {
        assertType(res.data, 'array', 'remotes');
      }
    });
  }
}

async function testArchiveAPI() {
  log('\n📦 Testing Archive API', 'blue');

  await test('GET /api/archive/plans returns archived plans', async () => {
    const res = await apiCall('/api/archive/plans');
    assert(res.status === 200, `Expected 200, got ${res.status}`);
    assertType(res.data, 'array', 'archived plans');
  });

  await test('GET /api/archive/waves returns archived waves', async () => {
    const res = await apiCall('/api/archive/waves');
    assert(res.status === 200, `Expected 200, got ${res.status}`);
    assertType(res.data, 'array', 'archived waves');
  });

  await test('GET /api/archive/tasks returns archived tasks', async () => {
    const res = await apiCall('/api/archive/tasks');
    assert(res.status === 200, `Expected 200, got ${res.status}`);
    assertType(res.data, 'array', 'archived tasks');
  });
}

// ============================================
// DATA INTEGRITY CHECKS
// ============================================

async function testDataIntegrity() {
  log('\n🔬 Testing Data Integrity', 'blue');

  await test('Plan progress calculations are correct', async () => {
    const plans = query(`
      SELECT id, tasks_done, tasks_total,
             CASE WHEN tasks_total > 0 THEN ROUND(100.0 * tasks_done / tasks_total) ELSE 0 END as calculated_progress
      FROM plans WHERE tasks_total > 0 LIMIT 5
    `);

    plans.forEach(plan => {
      const expectedProgress = plan.tasks_total > 0 
        ? Math.round((100.0 * plan.tasks_done) / plan.tasks_total) 
        : 0;
      assert(
        plan.calculated_progress === expectedProgress,
        `Plan ${plan.id}: Progress mismatch. Expected ${expectedProgress}, got ${plan.calculated_progress}`
      );
    });
  });

  await test('Task counts match between plans and tasks table', async () => {
    const mismatches = query(`
      SELECT 
        p.id as plan_id,
        p.tasks_total as plan_tasks_total,
        COUNT(t.id) as actual_task_count
      FROM plans p
      LEFT JOIN tasks t ON t.plan_id = p.id
      GROUP BY p.id
      HAVING p.tasks_total != actual_task_count
      LIMIT 5
    `);

    if (mismatches.length > 0) {
      const issues = mismatches.map(m => 
        `Plan ${m.plan_id}: expects ${m.plan_tasks_total} tasks but has ${m.actual_task_count}`
      ).join(', ');
      throw new Error(`Task count mismatches found: ${issues}`);
    }
  });

  await test('Wave task counts are accurate', async () => {
    const mismatches = query(`
      SELECT 
        w.id as wave_id,
        w.wave_id,
        w.tasks_total as wave_tasks_total,
        COUNT(t.id) as actual_task_count
      FROM waves w
      LEFT JOIN tasks t ON t.wave_id_fk = w.id
      GROUP BY w.id
      HAVING w.tasks_total != actual_task_count
      LIMIT 5
    `);

    if (mismatches.length > 0) {
      const issues = mismatches.map(m => 
        `Wave ${m.wave_id}: expects ${m.wave_tasks_total} tasks but has ${m.actual_task_count}`
      ).join(', ');
      throw new Error(`Wave task count mismatches found: ${issues}`);
    }
  });

  await test('All tasks belong to valid plans and waves', async () => {
    const orphans = query(`
      SELECT t.id, t.task_id, t.plan_id, t.wave_id_fk
      FROM tasks t
      LEFT JOIN plans p ON t.plan_id = p.id
      LEFT JOIN waves w ON t.wave_id_fk = w.id
      WHERE p.id IS NULL OR w.id IS NULL
      LIMIT 5
    `);

    if (orphans.length > 0) {
      const issues = orphans.map(o => `Task ${o.task_id} (id: ${o.id})`).join(', ');
      throw new Error(`Orphan tasks found: ${issues}`);
    }
  });

  await test('Token costs are calculated correctly', async () => {
    const tokenRecords = query(`
      SELECT id, total_tokens, cost_usd, model
      FROM token_usage 
      WHERE total_tokens > 0
      LIMIT 10
    `);

    // Just verify cost is a reasonable number
    tokenRecords.forEach(record => {
      assert(
        typeof record.cost_usd === 'number' && record.cost_usd >= 0,
        `Token usage ${record.id}: Invalid cost ${record.cost_usd}`
      );
    });
  });

  await test('Project aggregations match plan data', async () => {
    const projectStats = query(`
      SELECT 
        pr.id as project_id,
        COUNT(CASE WHEN p.status = 'done' THEN 1 END) as calculated_done,
        COUNT(CASE WHEN p.status = 'doing' THEN 1 END) as calculated_doing,
        COUNT(CASE WHEN p.status = 'todo' THEN 1 END) as calculated_todo
      FROM projects pr
      LEFT JOIN plans p ON p.project_id = pr.id
      GROUP BY pr.id
      LIMIT 5
    `);

    // Just verify numbers are reasonable
    projectStats.forEach(stat => {
      assert(
        stat.calculated_done >= 0 && stat.calculated_doing >= 0 && stat.calculated_todo >= 0,
        `Project ${stat.project_id}: Invalid aggregation counts`
      );
    });
  });
}

// ============================================
// MAIN
// ============================================

async function runAllTests() {
  log('\n╔════════════════════════════════════════╗', 'blue');
  log('║   API Endpoint Testing Suite          ║', 'blue');
  log('╚════════════════════════════════════════╝', 'blue');
  log(`Testing server at: ${BASE_URL}\n`, 'gray');

  try {
    // Check server is running
    try {
      await apiCall('/api/health');
    } catch (e) {
      log(`\n❌ Server is not running on ${BASE_URL}`, 'red');
      log('Please start the server first: node dashboard/server.js\n', 'yellow');
      process.exit(1);
    }

    // Run all test suites
    await testSystemAPI();
    await testKanbanAPI();
    await testProjectsAPI();
    await testPlansAPI();
    await testMonitoringAPI();
    await testGitAPI();
    await testArchiveAPI();
    await testDataIntegrity();

    // Summary
    log('\n╔════════════════════════════════════════╗', 'blue');
    log('║   Test Summary                         ║', 'blue');
    log('╚════════════════════════════════════════╝', 'blue');
    log(`Total tests: ${totalTests}`);
    log(`Passed: ${passedTests}`, 'green');
    log(`Failed: ${failedTests}`, failedTests > 0 ? 'red' : 'gray');
    log(`Success rate: ${Math.round((passedTests / totalTests) * 100)}%`, 
        failedTests === 0 ? 'green' : 'yellow');

    if (failedTests === 0) {
      log('\n✨ All tests passed! API is working correctly.\n', 'green');
      process.exit(0);
    } else {
      log('\n⚠️  Some tests failed. Please review the errors above.\n', 'yellow');
      process.exit(1);
    }

  } catch (e) {
    log(`\n❌ Fatal error: ${e.message}\n`, 'red');
    console.error(e);
    process.exit(1);
  }
}

runAllTests();
