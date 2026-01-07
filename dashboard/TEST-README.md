# Dashboard API Testing Suite

Comprehensive testing suite for the Dashboard API backend.

## Quick Start

```bash
# Start the server
./server.js 31415

# In another terminal, run tests
node test-api-endpoints.js      # Main functionality tests
node test-api-edge-cases.js     # Edge cases & validation
```

## Test Files

### `test-api-endpoints.js`
Tests all main API endpoints for correct functionality:
- System health checks
- Kanban & project management
- Plans, waves, and tasks
- Git integration
- GitHub integration
- Monitoring & sessions
- Archive functionality
- Data integrity

**Total Tests:** 25

### `test-api-edge-cases.js`
Tests edge cases, error handling, and data validation:
- Invalid input handling
- Empty result sets
- Boundary conditions
- Data consistency checks
- API response consistency
- Performance benchmarks

**Total Tests:** 27

## Test Results

Both test suites provide colored output:
- ✅ Green = Passed
- ❌ Red = Failed
- ℹ️  Gray = Running

### Example Output

```
╔════════════════════════════════════════╗
║   API Endpoint Testing Suite          ║
╚════════════════════════════════════════╝

📊 Testing System API
  ✓ GET /api/health returns healthy status

📋 Testing Kanban API
  ✓ GET /api/kanban returns array of projects

...

╔════════════════════════════════════════╗
║   Test Summary                         ║
╚════════════════════════════════════════╝
Total tests: 25
Passed: 25
Failed: 0
Success rate: 100%

✨ All tests passed! API is working correctly.
```

## Requirements

- Node.js v14+
- Dashboard server running on port 31415
- SQLite database at `~/.claude/data/dashboard.db`

## Test Categories

### System APIs
Health checks, server status, uptime monitoring

### Project Management
Projects, plans, waves, tasks, kanban views

### Git Integration
Status, branches, remotes, commits

### GitHub Integration
Issues, pull requests, repository data

### Monitoring
Active sessions, conversations, executor status

### Archive
Archived plans, waves, and tasks

### Data Integrity
- Referential integrity checks
- Progress calculation validation
- Count consistency verification
- Status enum validation
- Timestamp validation

### Performance
- Response time benchmarks
- Query optimization checks

## Exit Codes

- `0` - All tests passed
- `1` - One or more tests failed

## CI/CD Integration

```bash
# Example CI script
#!/bin/bash
set -e

# Start server in background
./server.js 31415 > /tmp/server.log 2>&1 &
SERVER_PID=$!

# Wait for server to start
sleep 2

# Run tests
node test-api-endpoints.js
node test-api-edge-cases.js

# Cleanup
kill $SERVER_PID
```

## Development

### Adding New Tests

```javascript
async function testNewFeature() {
  log('\n🔧 Testing New Feature', 'blue');

  await test('Description of what is tested', async () => {
    const res = await apiCall('/api/new-endpoint');
    assert(res.status === 200, 'Should return 200');
    assert(res.data.field === 'expected', 'Field should match');
  });
}
```

### Helper Functions

- `apiCall(path, method, body)` - Make HTTP request
- `test(description, testFn)` - Run a test
- `assert(condition, message)` - Assert condition
- `assertType(value, type, name)` - Assert type
- `assertHasKeys(obj, keys, name)` - Assert object has keys

## Troubleshooting

### Server not running
```
❌ Server is not running on http://localhost:31415
Please start the server first: node dashboard/server.js
```
**Solution:** Start the server with `./server.js 31415`

### Port already in use
```
Port 31415 in use, trying 31416...
```
**Solution:** Kill existing process: `lsof -ti:31415 | xargs kill`

### Database errors
```
Error: SQLITE_ERROR: no such table: tasks
```
**Solution:** Check database path in `server/db.js`

## Reports

Full test reports are generated in:
- `API-TEST-REPORT.md` - Detailed test results and findings

## License

MIT
