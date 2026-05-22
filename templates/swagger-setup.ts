/**
 * Swagger/OpenAPI Setup Template
 *
 * Copy this file to each service as src/swagger.ts
 * Update SERVICE_NAME, SERVICE_DESCRIPTION, and PORT
 */

import swaggerJsdoc from 'swagger-jsdoc';
import swaggerUi from 'swagger-ui-express';
import { Express } from 'express';

// TODO: Update these values for each service
const SERVICE_NAME = 'User Service';
const SERVICE_DESCRIPTION = 'User authentication and management';
const SERVICE_VERSION = '1.0.0';
const SERVICE_PORT = 3002;

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: `LicenseGuard ${SERVICE_NAME} API`,
      version: SERVICE_VERSION,
      description: SERVICE_DESCRIPTION,
      contact: {
        name: 'LicenseGuard Development Team',
        email: 'dev@licenseguard.local'
      },
      license: {
        name: 'MIT',
        url: 'https://opensource.org/licenses/MIT'
      }
    },
    servers: [
      {
        url: `http://api.lg.local`,
        description: 'Local development (Traefik proxy)'
      },
      {
        url: `http://localhost:${SERVICE_PORT}`,
        description: 'Direct service access (no proxy)'
      }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'JWT token from /user/login'
        },
        internalApiKey: {
          type: 'apiKey',
          in: 'header',
          name: 'X-Internal-API-Key',
          description: 'Internal service-to-service authentication'
        }
      },
      schemas: {
        Error: {
          type: 'object',
          properties: {
            error: {
              type: 'object',
              properties: {
                code: {
                  type: 'string',
                  example: 'VALIDATION_ERROR'
                },
                message: {
                  type: 'string',
                  example: 'Email is required'
                },
                timestamp: {
                  type: 'string',
                  format: 'date-time'
                }
              }
            }
          }
        },
        HealthResponse: {
          type: 'object',
          properties: {
            status: {
              type: 'string',
              enum: ['healthy', 'unhealthy'],
              example: 'healthy'
            },
            timestamp: {
              type: 'string',
              format: 'date-time'
            },
            service: {
              type: 'string',
              example: SERVICE_NAME
            },
            version: {
              type: 'string',
              example: SERVICE_VERSION
            }
          }
        }
      },
      responses: {
        UnauthorizedError: {
          description: 'Authentication required or failed',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: {
                  code: 'UNAUTHORIZED',
                  message: 'Authentication required',
                  timestamp: '2026-01-25T10:30:00Z'
                }
              }
            }
          }
        },
        ForbiddenError: {
          description: 'Insufficient permissions',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: {
                  code: 'FORBIDDEN',
                  message: 'Insufficient permissions',
                  timestamp: '2026-01-25T10:30:00Z'
                }
              }
            }
          }
        },
        NotFoundError: {
          description: 'Resource not found',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: {
                  code: 'NOT_FOUND',
                  message: 'Resource not found',
                  timestamp: '2026-01-25T10:30:00Z'
                }
              }
            }
          }
        },
        ValidationError: {
          description: 'Invalid request data',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: {
                  code: 'VALIDATION_ERROR',
                  message: 'Email is required',
                  timestamp: '2026-01-25T10:30:00Z'
                }
              }
            }
          }
        },
        InternalError: {
          description: 'Internal server error',
          content: {
            'application/json': {
              schema: {
                $ref: '#/components/schemas/Error'
              },
              example: {
                error: {
                  code: 'INTERNAL_ERROR',
                  message: 'An unexpected error occurred',
                  timestamp: '2026-01-25T10:30:00Z'
                }
              }
            }
          }
        }
      }
    },
    tags: [
      {
        name: 'Health',
        description: 'Service health check endpoints'
      },
      // TODO: Add service-specific tags
    ]
  },
  apis: [
    './src/routes/*.ts',
    './src/routes/*.js',
    './src/server.ts'
  ]
};

const swaggerSpec = swaggerJsdoc(options);

export function setupSwagger(app: Express): void {
  // Serve swagger JSON
  app.get('/api-docs.json', (req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.send(swaggerSpec);
  });

  // Serve Swagger UI
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: `${SERVICE_NAME} API Documentation`
  }));

  console.log(`📚 Swagger UI available at http://localhost:${SERVICE_PORT}/api-docs`);
  console.log(`📄 OpenAPI JSON available at http://localhost:${SERVICE_PORT}/api-docs.json`);
}

export default swaggerSpec;
