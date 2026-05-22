/**
 * Prometheus Metrics Middleware Template
 *
 * Copy this file to each service as src/middleware/metrics.ts
 * Update SERVICE_NAME for each service
 */

import express from 'express';
import promClient from 'prom-client';

// Initialize Prometheus client
const register = new promClient.Registry();

// Add default metrics (CPU, memory, event loop, etc.)
promClient.collectDefaultMetrics({
  register,
  prefix: 'nodejs_',
  gcDurationBuckets: [0.001, 0.01, 0.1, 1, 2, 5]
});

// TODO: Update SERVICE_NAME for each service
const SERVICE_NAME = 'user-service';

// Custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code', 'service'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 2, 5, 10]
});

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code', 'service']
});

const httpRequestsInProgress = new promClient.Gauge({
  name: 'http_requests_in_progress',
  help: 'Number of HTTP requests currently being processed',
  labelNames: ['method', 'service']
});

const databaseQueryDuration = new promClient.Histogram({
  name: 'database_query_duration_seconds',
  help: 'Duration of database queries in seconds',
  labelNames: ['query_type', 'table', 'service'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 2, 5]
});

const databaseConnectionsActive = new promClient.Gauge({
  name: 'database_connections_active',
  help: 'Number of active database connections',
  labelNames: ['service']
});

const redisOperationDuration = new promClient.Histogram({
  name: 'redis_operation_duration_seconds',
  help: 'Duration of Redis operations in seconds',
  labelNames: ['operation', 'service'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1]
});

const businessMetricsCounter = new promClient.Counter({
  name: 'business_operations_total',
  help: 'Total number of business operations',
  labelNames: ['operation', 'status', 'service']
});

// Register custom metrics
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestsTotal);
register.registerMetric(httpRequestsInProgress);
register.registerMetric(databaseQueryDuration);
register.registerMetric(databaseConnectionsActive);
register.registerMetric(redisOperationDuration);
register.registerMetric(businessMetricsCounter);

/**
 * Middleware to track HTTP metrics
 */
export function metricsMiddleware(req: express.Request, res: express.Response, next: express.NextFunction): void {
  const start = Date.now();

  // Track request in progress
  httpRequestsInProgress.inc({ method: req.method, service: SERVICE_NAME });

  // Capture response finish
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000; // Convert to seconds
    const route = req.route?.path || req.path || 'unknown';

    // Record metrics
    httpRequestDuration.observe(
      {
        method: req.method,
        route,
        status_code: res.statusCode,
        service: SERVICE_NAME
      },
      duration
    );

    httpRequestsTotal.inc({
      method: req.method,
      route,
      status_code: res.statusCode,
      service: SERVICE_NAME
    });

    httpRequestsInProgress.dec({ method: req.method, service: SERVICE_NAME });
  });

  next();
}

/**
 * Metrics endpoint handler
 */
export async function metricsHandler(req: express.Request, res: express.Response): Promise<void> {
  try {
    res.set('Content-Type', register.contentType);
    const metrics = await register.metrics();
    res.end(metrics);
  } catch (error) {
    res.status(500).end(error);
  }
}

/**
 * Track database query
 */
export function trackDatabaseQuery(queryType: string, table: string): () => void {
  const end = databaseQueryDuration.startTimer({
    query_type: queryType,
    table,
    service: SERVICE_NAME
  });

  return end;
}

/**
 * Track Redis operation
 */
export function trackRedisOperation(operation: string): () => void {
  const end = redisOperationDuration.startTimer({
    operation,
    service: SERVICE_NAME
  });

  return end;
}

/**
 * Track business metric
 */
export function trackBusinessMetric(operation: string, status: 'success' | 'failure'): void {
  businessMetricsCounter.inc({
    operation,
    status,
    service: SERVICE_NAME
  });
}

/**
 * Update database connections gauge
 */
export function updateDatabaseConnections(count: number): void {
  databaseConnectionsActive.set({ service: SERVICE_NAME }, count);
}

/**
 * Example usage in service
 *
 * // In server.ts:
 * import { metricsMiddleware, metricsHandler } from './middleware/metrics';
 *
 * app.use(metricsMiddleware);
 * app.get('/metrics', metricsHandler);
 *
 * // In database layer:
 * import { trackDatabaseQuery } from './middleware/metrics';
 *
 * async function findUser(id: string) {
 *   const endTimer = trackDatabaseQuery('SELECT', 'users');
 *   const user = await db.query('SELECT * FROM users WHERE id = $1', [id]);
 *   endTimer();
 *   return user;
 * }
 *
 * // For business metrics:
 * import { trackBusinessMetric } from './middleware/metrics';
 *
 * try {
 *   await createUser(userData);
 *   trackBusinessMetric('user_registration', 'success');
 * } catch (error) {
 *   trackBusinessMetric('user_registration', 'failure');
 *   throw error;
 * }
 */

export {
  register,
  httpRequestDuration,
  httpRequestsTotal,
  databaseQueryDuration,
  redisOperationDuration,
  businessMetricsCounter
};
