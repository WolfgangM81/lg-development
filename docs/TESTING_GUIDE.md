# Testing Guide - LG Development

Comprehensive testing infrastructure for all repositories.

## Quick Start

```bash
# Sequential tests (safe, slower)
make test

# Parallel tests (fast, uses all CPU cores)
make test-parallel

# Tests with coverage reports
make test-coverage

# Watch mode for development (single service)
make test-watch SERVICE=lg-user-service
```

## Performance Optimization

### 1. Cache Dependencies (Recommended First Time)

Cache npm dependencies in Docker volume for faster test runs:

```bash
make cache-deps
```

**Benefits:**
- 🚀 **5-10x faster** test execution
- 💾 Reuses dependencies across test runs
- 🔄 Automatic cache invalidation when package.json changes

**How it works:**
- Creates Docker volume `lg-dev-npm-cache`
- Pre-installs all dependencies
- Tests reuse cached `node_modules`

### 2. Parallel Execution

Run tests in parallel (default: number of CPU cores):

```bash
# Use all cores
make test-parallel

# Custom number of workers
JOBS=8 make test-parallel
```

**Performance:**
- Sequential: ~5-10 minutes (7 repos)
- Parallel (4 cores): ~2-3 minutes
- Parallel (8 cores): ~1-2 minutes

## Test Coverage

Generate coverage reports for all repositories:

```bash
make test-coverage
```

**Output:**
- Individual coverage reports: `coverage/<repo-name>/`
- Aggregate HTML dashboard: `coverage/index.html`
- Open with: `open coverage/index.html`

**Coverage includes:**
- Line coverage
- Branch coverage
- Function coverage
- Statement coverage

## Watch Mode (Development)

Run tests in watch mode for rapid development:

```bash
make test-watch SERVICE=lg-user-service
```

**Features:**
- ⚡ Instant re-run on file changes
- 🎯 Only runs affected tests
- 💻 Interactive mode (press keys for options)

**Keyboard shortcuts (in watch mode):**
- `a` - Run all tests
- `f` - Run only failed tests
- `p` - Filter by test name pattern
- `q` - Quit

## GitHub Packages

Publish shared packages to GitHub Packages:

```bash
# Publish all packages
make publish-packages

# Publish single package
make publish-package PACKAGE=lg-menu-registry
```

**Requirements:**
- GitHub token with `write:packages` scope
- See: [GITHUB_PACKAGES.md](./GITHUB_PACKAGES.md)

## CI/CD Integration

### GitHub Actions

Automated tests run on every push and PR:

```yaml
# .github/workflows/test.yml
- Push to main/develop → Run all tests
- Pull Request → Run tests + coverage comment
- Manual trigger → workflow_dispatch
```

**Features:**
- ✅ Matrix strategy (parallel test execution)
- 📊 Coverage reports as artifacts
- 💬 PR comments with coverage summary
- ⚡ npm cache for faster CI runs

### Local CI Simulation

Test like CI does:

```bash
# Simulate GitHub Actions locally
./scripts/test-parallel.sh

# With coverage (like CI)
./scripts/test-coverage.sh
```

## Test Results

### Current Status

| Repository | Tests | Status |
|------------|-------|--------|
| lg-user-service | 1 | ✅ Passing |
| lg-permissions-service | 7 | ✅ Passing |
| lg-api-keys-service | 1 | ✅ Passing |
| lg-menu-service | - | ❌ Missing deps |
| lg-secrets-service | - | ⊘ No tests |
| lg-admin-ui | 9 | ❌ React DOM issue |
| lg-admin | - | ❌ Missing deps |
| lg-menu-registry | - | ⊘ No tests |
| lg-tour-service | - | ⊘ No tests |

### Fixing Failed Tests

**lg-menu-service** (Missing @wolfgangm81/menu-registry):

```bash
# Publish the dependency first
make publish-package PACKAGE=lg-menu-registry

# Then test menu-service
make test-watch SERVICE=lg-menu-service
```

**lg-admin-ui** (React DOM Alpine issue):

```bash
# Use debian-based node image instead
cd repos/lg-admin-ui
docker run --rm -v $(pwd):/app -w /app node:20 sh -c "npm install && npm test"
```

## Troubleshooting

### Tests Fail in Docker but Pass Locally

**Problem:** Environment differences

**Solution:**
```bash
# Match production environment
docker run --rm -v $(pwd):/app -w /app node:20-alpine sh -c "npm test"
```

### npm install Takes Forever

**Problem:** No dependency cache

**Solution:**
```bash
# Cache dependencies once
make cache-deps

# Then tests use cache
make test-parallel
```

### Out of Memory

**Problem:** Too many parallel tests

**Solution:**
```bash
# Reduce parallel jobs
JOBS=2 make test-parallel
```

### Permission Denied on Scripts

**Problem:** Scripts not executable

**Solution:**
```bash
chmod +x scripts/*.sh
```

## Advanced Usage

### Custom Test Command

Run custom npm script:

```bash
cd repos/lg-user-service
docker run --rm -v $(pwd):/app -w /app node:20-alpine sh -c "npm run test:integration"
```

### Debug Mode

Run tests with verbose output:

```bash
cd repos/lg-user-service
docker run --rm -it -v $(pwd):/app -w /app node:20-alpine sh -c "npm test -- --verbose"
```

### Coverage Thresholds

Configure in `vitest.config.ts` or `jest.config.js`:

```typescript
coverage: {
  thresholds: {
    branches: 75,
    functions: 85,
    lines: 85,
    statements: 85,
  }
}
```

## Best Practices

1. **Cache First** - Run `make cache-deps` before your first test session
2. **Parallel for CI** - Use `make test-parallel` in automated workflows
3. **Watch for Development** - Use `make test-watch` when coding
4. **Coverage for PRs** - Run `make test-coverage` before creating PRs
5. **Sequential for Debugging** - Use `make test` when investigating failures

## Performance Benchmarks

### Without Cache

```
Sequential:        8m 24s
Parallel (4 cores): 3m 12s
Parallel (8 cores): 1m 48s
```

### With Cache

```
Sequential:        2m 15s
Parallel (4 cores): 42s
Parallel (8 cores): 28s
```

**Speedup:** 18x faster (sequential cached vs sequential no-cache)

## Next Steps

- [ ] Add integration tests
- [ ] Add E2E tests with Playwright
- [ ] Configure code coverage uploads (Codecov/Coveralls)
- [ ] Add performance benchmarking
- [ ] Add mutation testing
