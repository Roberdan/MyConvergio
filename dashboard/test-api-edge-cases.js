#!/usr/bin/env node
// Edge Cases and Input Validation Testing
// Tests error handling, invalid inputs, and boundary conditions

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

// ============================================
// EDGE CASE TESTS
// ============================================

async function testInvalidInputs() {
  log('\n🔒 Testing Invalid Inputs & Error Handling', 'blue');

  await test('GET /api/plan with invalid ID returns error', async () => {
    const res = await apiCall('/api/plan/99999999');
    assert(res.status === 200, 'Should still return 200');
    assert(res.data.error, 'Should have error field');
    assert(res.data.error.includes('not found'), 'Should indicate not found');
  });

  await test('GET /api/plan with non-numeric ID returns error', async () => {
    const res = await apiCall('/api/plan/invalid');
    assert(res.status === 200, 'Should still return 200');
    assert(res.data.error, 'Should have error field');
  });

  await test('GET /api/project with non-existent project returns error', async () => {
    const res = await apiCall('/api/project/nonexistent/dashboard');
    assert(res.status === 200, 'Should still return 200');
    assert(res.data.error, 'Should have error field');
  });

  await test('GET /api/plans with SQL injection attempt is handled safely', async () => {
    const maliciousInput = "'; DROP TABLE plans; --";
    const res = await apiCall(`/api/plans/${encodeURIComponent(maliciousInput)}`);
    // Should not crash and should return empty or error
    assert(res.status === 200, 'Should return 200');
    assert(Array.isArray(res.data) || res.data.error, 'Should return array or error');
  });

  await test('GET /api/project/:id/git with invalid project returns error', async () => {
    const res = await apiCall('/api/project/nonexistent/git');
    assert(res.status === 200, 'Should return 200');
    assert(res.data.error, 'Should have error field');
  });

  await test('GET /api/project/:id/github with invalid project returns error', async () => {
    const res = await apiCall('/api/project/nonexistent/github');
    assert(res.status === 200, 'Should return 200');
    assert(res.data.error, 'Should have error field');
  });
}

async function testEmptyResults() {
  log('\n📭 Testing Empty Results', 'blue');

  await test('GET /api/kanban with no data returns empty array', async () => {
    const res = await apiCall('/api/kanban');
    assert(res.status === 200, 'Should return 200');
    assert(Array.isArray(res.data), 'Should return array');
  });

  await test('GET /api/monitoring/sessions handles no active sessions', async () => {
    const res = await apiCall('/api/monitoring/sessions');
    assert(res.status === 200, 'Should return 200');
    assert(Array.isArray(res.data), 'Should return array');
  });

  await test('GET /api/archive/plans handles no archived plans', async () => {
    const res = await apiCall('/api/archive/plans');
    assert(res.status === 200, 'Should return 200');
    assert(Array.isArray(res.data), 'Should return array');
  });
}

async function testBoundaryConditions() {
  log('\n🎯 Testing Boundary Conditions', 'blue');

  // Get a real project for boundary tests
  const projectsRes = await apiCall('/api/projects');
  if (projectsRes.data.length === 0) {
    log('  Skipping boundary tests - no projects found', 'yellow');
    return;
  }
  
  const projectId = projectsRes.data[0].project_id;

  await test('Progress calculation with 0 tasks is correct', async () => {
    const plans = query(`
      SELECT id, tasks_done, tasks_total,
             CASE WHEN tasks_total > 0 THEN ROUND(100.0 * tasks_done / tasks_total) ELSE 0 END as progress
      FROM plans WHERE tasks_total = 0 LIMIT 1
    `);
    
    if (plans.length > 0) {
      assert(plans[0].progress === 0, 'Progress with 0 tasks should be 0');
    }
  });

  await test('Progress calculation with all tasks done is 100%', async () => {
    const plans = query(`
      SELECT id, tasks_done, tasks_total,
             CASE WHEN tasks_total > 0 THEN ROUND(100.0 * tasks_done / tasks_total) ELSE 0 END as progress
      FROM plans 
      WHERE tasks_total > 0 AND tasks_done = tasks_total 
      LIMIT 1
    `);
    
    if (plans.length > 0) {
      assert(plans[0].progress === 100, `Progress with all tasks done should be 100, got ${plans[0].progress}`);
    }
  });

  await test('Token stats handle 0 tokens gracefully', async () => {
    const res = await apiCall(`/api/project/${projectId}/tokens`);
    assert(res.status === 200, 'Should return 200');
    assert(typeof res.data.stats.total_tokens === 'number', 'Total tokens should be number');
    assert(res.data.stats.total_tokens >= 0, 'Total tokens should be >= 0');
  });

  await test('Git status handles empty repository gracefully', async () => {
    const res = await apiCall(`/api/project/${projectId}/git`);
    if (!res.data.error) {
      assert(Array.isArray(res.data.staged), 'staged should be array');
      assert(Array.isArray(res.data.unstaged), 'unstaged should be array');
      assert(Array.isArray(res.data.untracked), 'untracked should be array');
      assert(Array.isArray(res.data.commits), 'commits should be array');
    }
  });
}

async function testDataConsistency() {
  log('\n🔍 Testing Data Consistency & Relationships', 'blue');

  await test('All plans have valid project references', async () => {
    const orphans = query(`
      SELECT p.id, p.project_id 
      FROM plans p
      LEFT JOIN projects pr ON p.project_id = pr.id
      WHERE pr.id IS NULL
      LIMIT 1
    `);
    assert(orphans.length === 0, `Found orphan plans without valid projects: ${JSON.stringify(orphans)}`);
  });

  await test('All waves have valid plan references', async () => {
    const orphans = query(`
      SELECT w.id, w.plan_id
      FROM waves w
      LEFT JOIN plans p ON w.plan_id = p.id
      WHERE p.id IS NULL
      LIMIT 1
    `);
    assert(orphans.length === 0, `Found orphan waves without valid plans: ${JSON.stringify(orphans)}`);
  });

  await test('Tasks done counts never exceed tasks total', async () => {
    const invalid = query(`
      SELECT id, name, tasks_done, tasks_total
      FROM plans
      WHERE tasks_done > tasks_total
      LIMIT 5
    `);
    assert(invalid.length === 0, `Found plans with tasks_done > tasks_total: ${JSON.stringify(invalid)}`);
  });

  await test('Wave tasks done counts never exceed wave tasks total', async () => {
    const invalid = query(`
      SELECT id, wave_id, tasks_done, tasks_total
      FROM waves
      WHERE tasks_done > tasks_total
      LIMIT 5
    `);
    assert(invalid.length === 0, `Found waves with tasks_done > tasks_total: ${JSON.stringify(invalid)}`);
  });

  await test('Task statuses are valid enum values', async () => {
    const validStatuses = ['pending', 'in_progress', 'done', 'blocked', 'skipped'];
    const invalid = query(`
      SELECT id, task_id, status
      FROM tasks
      WHERE status NOT IN ('pending', 'in_progress', 'done', 'blocked', 'skipped')
      LIMIT 5
    `);
    assert(invalid.length === 0, `Found tasks with invalid status: ${JSON.stringify(invalid)}`);
  });

  await test('Plan statuses are valid enum values', async () => {
    const invalid = query(`
      SELECT id, name, status
      FROM plans
      WHERE status NOT IN ('todo', 'doing', 'done')
      LIMIT 5
    `);
    assert(invalid.length === 0, `Found plans with invalid status: ${JSON.stringify(invalid)}`);
  });

  await test('Token usage records have non-negative costs', async () => {
    const invalid = query(`
      SELECT id, cost_usd, total_tokens
      FROM token_usage
      WHERE cost_usd < 0 OR total_tokens < 0
      LIMIT 5
    `);
    assert(invalid.length === 0, `Found token records with negative values: ${JSON.stringify(invalid)}`);
  });

  await test('Completed tasks have completion timestamps', async () => {
    const invalid = query(`
      SELECT id, task_id, status, completed_at
      FROM tasks
      WHERE status = 'done' AND completed_at IS NULL
      LIMIT 5
    `);
    if (invalid.length > 0) {
      log(`    Warning: Found ${invalid.length} completed tasks without timestamps`, 'yellow');
    }
  });
}

async function testAPIConsistency() {
  log('\n⚖️  Testing API Response Consistency', 'blue');

  const projectsRes = await apiCall('/api/projects');
  if (projectsRes.data.length === 0) {
    log('  Skipping API consistency tests - no projects found', 'yellow');
    return;
  }

  const project = projectsRes.data[0];
  const projectId = project.project_id;

  await test('Project plans count matches between endpoints', async () => {
    const projectData = await apiCall('/api/projects');
    const plansData = await apiCall(`/api/plans/${projectId}`);
    
    const projectPlansTotal = projectData.data.find(p => p.project_id === projectId)?.plans_total || 0;
    const actualPlansCount = plansData.data.length;
    
    assert(
      projectPlansTotal === actualPlansCount,
      `Project reports ${projectPlansTotal} plans but /api/plans returns ${actualPlansCount}`
    );
  });

  await test('Dashboard metrics match raw data', async () => {
    const dashboard = await apiCall(`/api/project/${projectId}/dashboard`);
    const plans = await apiCall(`/api/plans/${projectId}`);
    
    const donePlans = plans.data.filter(p => p.status === 'done').length;
    const dashboardDone = dashboard.data.plans.done;
    
    assert(
      donePlans === dashboardDone,
      `Dashboard shows ${dashboardDone} done plans but actual count is ${donePlans}`
    );
  });

  await test('Plan task counts match task endpoint', async () => {
    const plans = await apiCall(`/api/plans/${projectId}`);
    
    if (plans.data.length > 0) {
      const plan = plans.data[0];
      const planDetails = await apiCall(`/api/plan/${plan.id}`);
      
      let totalTasks = 0;
      let doneTasks = 0;
      
      planDetails.data.waves?.forEach(wave => {
        wave.tasks?.forEach(task => {
          totalTasks++;
          if (task.status === 'done') doneTasks++;
        });
      });
      
      assert(
        totalTasks === plan.tasks_total,
        `Plan ${plan.id} reports ${plan.tasks_total} total tasks but has ${totalTasks}`
      );
      assert(
        doneTasks === plan.tasks_done,
        `Plan ${plan.id} reports ${plan.tasks_done} done tasks but has ${doneTasks}`
      );
    }
  });
}

async function testPerformance() {
  log('\n⚡ Testing Performance & Response Times', 'blue');

  await test('Health check responds quickly (< 100ms)', async () => {
    const start = Date.now();
    await apiCall('/api/health');
    const duration = Date.now() - start;
    assert(duration < 100, `Health check took ${duration}ms, expected < 100ms`);
  });

  await test('Projects list responds quickly (< 500ms)', async () => {
    const start = Date.now();
    await apiCall('/api/projects');
    const duration = Date.now() - start;
    assert(duration < 500, `Projects list took ${duration}ms, expected < 500ms`);
  });

  await test('Kanban view responds quickly (< 500ms)', async () => {
    const start = Date.now();
    await apiCall('/api/kanban');
    const duration = Date.now() - start;
    assert(duration < 500, `Kanban view took ${duration}ms, expected < 500ms`);
  });
}

// ============================================
// MAIN
// ============================================

async function runAllTests() {
  log('\n╔════════════════════════════════════════╗', 'blue');
  log('║   Edge Cases & Validation Testing     ║', 'blue');
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
    await testInvalidInputs();
    await testEmptyResults();
    await testBoundaryConditions();
    await testDataConsistency();
    await testAPIConsistency();
    await testPerformance();

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
      log('\n✨ All edge case tests passed! APIs are robust.\n', 'green');
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
