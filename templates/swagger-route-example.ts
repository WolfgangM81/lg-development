/**
 * Example route file with OpenAPI/Swagger annotations
 *
 * Shows how to document REST API endpoints using JSDoc comments
 */

import express from 'express';
import { authMiddleware } from '@wolfgangm81/lg-backend-common';

const router = express.Router();

/**
 * @swagger
 * /user/health:
 *   get:
 *     summary: Health check endpoint
 *     description: Check if the user service is healthy
 *     tags:
 *       - Health
 *     responses:
 *       200:
 *         description: Service is healthy
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/HealthResponse'
 *             example:
 *               status: healthy
 *               timestamp: '2026-01-25T10:30:00Z'
 *               service: 'User Service'
 *               version: '1.0.0'
 */
router.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'User Service',
    version: '1.0.0'
  });
});

/**
 * @swagger
 * /user/register:
 *   post:
 *     summary: Register a new user
 *     description: Create a new user account
 *     tags:
 *       - Authentication
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *               - firstName
 *               - lastName
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: user@example.com
 *               password:
 *                 type: string
 *                 format: password
 *                 minLength: 8
 *                 example: SecurePass123!
 *               firstName:
 *                 type: string
 *                 example: John
 *               lastName:
 *                 type: string
 *                 example: Doe
 *     responses:
 *       201:
 *         description: User created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *                 token:
 *                   type: string
 *                   example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 *       400:
 *         $ref: '#/components/responses/ValidationError'
 *       409:
 *         description: Email already exists
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               error:
 *                 code: EMAIL_EXISTS
 *                 message: Email already registered
 *       500:
 *         $ref: '#/components/responses/InternalError'
 */
router.post('/register', async (req, res) => {
  // Implementation here
});

/**
 * @swagger
 * /user/login:
 *   post:
 *     summary: Login user
 *     description: Authenticate user and return JWT token
 *     tags:
 *       - Authentication
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: user@example.com
 *               password:
 *                 type: string
 *                 format: password
 *                 example: SecurePass123!
 *     responses:
 *       200:
 *         description: Login successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *                 token:
 *                   type: string
 *                   description: JWT authentication token
 *                   example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 *       401:
 *         description: Invalid credentials
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               error:
 *                 code: INVALID_CREDENTIALS
 *                 message: Email or password is incorrect
 *       500:
 *         $ref: '#/components/responses/InternalError'
 */
router.post('/login', async (req, res) => {
  // Implementation here
});

/**
 * @swagger
 * /user/me:
 *   get:
 *     summary: Get current user
 *     description: Get the currently authenticated user's profile
 *     tags:
 *       - User
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User profile
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/User'
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       500:
 *         $ref: '#/components/responses/InternalError'
 */
router.get('/me', authMiddleware, async (req, res) => {
  // Implementation here
});

/**
 * @swagger
 * /user/me:
 *   put:
 *     summary: Update current user
 *     description: Update the currently authenticated user's profile
 *     tags:
 *       - User
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               firstName:
 *                 type: string
 *                 example: John
 *               lastName:
 *                 type: string
 *                 example: Doe
 *               email:
 *                 type: string
 *                 format: email
 *                 example: newemail@example.com
 *     responses:
 *       200:
 *         description: Profile updated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/User'
 *       400:
 *         $ref: '#/components/responses/ValidationError'
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       409:
 *         description: Email already exists
 *       500:
 *         $ref: '#/components/responses/InternalError'
 */
router.put('/me', authMiddleware, async (req, res) => {
  // Implementation here
});

/**
 * @swagger
 * components:
 *   schemas:
 *     User:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *           example: 550e8400-e29b-41d4-a716-446655440000
 *         email:
 *           type: string
 *           format: email
 *           example: user@example.com
 *         firstName:
 *           type: string
 *           example: John
 *         lastName:
 *           type: string
 *           example: Doe
 *         createdAt:
 *           type: string
 *           format: date-time
 *           example: '2026-01-25T10:30:00Z'
 *         lastLogin:
 *           type: string
 *           format: date-time
 *           example: '2026-01-25T10:30:00Z'
 *           nullable: true
 */

export default router;
