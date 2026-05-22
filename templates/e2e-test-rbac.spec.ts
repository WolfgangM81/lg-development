/**
 * RBAC End-to-End Test Template
 *
 * This template demonstrates comprehensive RBAC testing scenarios
 * Copy to repos/infrastructure/lg-e2e-tests/tests/rbac/
 */

import { test, expect } from '@playwright/test';

const API_BASE_URL = process.env.API_URL || 'http://api.lg.local';

// Test data
const adminUser = {
  email: 'admin@test.com',
  password: 'AdminPass123!',
  firstName: 'Admin',
  lastName: 'User'
};

const regularUser = {
  email: 'user@test.com',
  password: 'UserPass123!',
  firstName: 'Regular',
  lastName: 'User'
};

let adminToken: string;
let regularUserToken: string;
let orgUnitId: string;
let roleId: string;

test.describe('RBAC E2E Tests', () => {
  test.beforeAll(async ({ request }) => {
    // Setup: Create admin user and get token
    const adminRegister = await request.post(`${API_BASE_URL}/user/register`, {
      data: adminUser
    });
    expect(adminRegister.ok()).toBeTruthy();
    const adminData = await adminRegister.json();
    adminToken = adminData.token;

    // Setup: Create regular user and get token
    const userRegister = await request.post(`${API_BASE_URL}/user/register`, {
      data: regularUser
    });
    expect(userRegister.ok()).toBeTruthy();
    const userData = await userRegister.json();
    regularUserToken = userData.token;
  });

  test('Scenario 1: Admin creates organizational unit', async ({ request }) => {
    const response = await request.post(`${API_BASE_URL}/permissions/rbac/organizational-units`, {
      headers: {
        Authorization: `Bearer ${adminToken}`
      },
      data: {
        name: 'Engineering Department',
        description: 'Software engineering teams'
      }
    });

    expect(response.status()).toBe(201);
    const orgUnit = await response.json();
    expect(orgUnit.name).toBe('Engineering Department');
    expect(orgUnit.id).toBeDefined();

    orgUnitId = orgUnit.id;
  });

  test('Scenario 2: Admin assigns user to organizational unit', async ({ request }) => {
    const response = await request.post(`${API_BASE_URL}/permissions/rbac/user-assignments`, {
      headers: {
        Authorization: `Bearer ${adminToken}`
      },
      data: {
        userId: regularUserToken, // In real implementation, get user ID from token
        orgUnitId: orgUnitId
      }
    });

    expect(response.status()).toBe(201);
    const assignment = await response.json();
    expect(assignment.orgUnitId).toBe(orgUnitId);
  });

  test('Scenario 3: Admin creates role with permissions', async ({ request }) => {
    const response = await request.post(`${API_BASE_URL}/permissions/rbac/roles`, {
      headers: {
        Authorization: `Bearer ${adminToken}`
      },
      data: {
        name: 'Developer',
        description: 'Software developer role',
        permissions: [
          { resource: 'documents', action: 'read' },
          { resource: 'documents', action: 'create' },
          { resource: 'code', action: 'read' },
          { resource: 'code', action: 'update' }
        ]
      }
    });

    expect(response.status()).toBe(201);
    const role = await response.json();
    expect(role.name).toBe('Developer');
    expect(role.permissions).toHaveLength(4);

    roleId = role.id;
  });

  test('Scenario 4: Admin assigns role to user in OU', async ({ request }) => {
    const response = await request.post(`${API_BASE_URL}/permissions/rbac/role-assignments`, {
      headers: {
        Authorization: `Bearer ${adminToken}`
      },
      data: {
        userId: regularUserToken,
        orgUnitId: orgUnitId,
        roleId: roleId
      }
    });

    expect(response.status()).toBe(201);
  });

  test('Scenario 5: User accesses permitted resource (success)', async ({ request }) => {
    const response = await request.post(`${API_BASE_URL}/permissions/rbac/check-access`, {
      headers: {
        Authorization: `Bearer ${regularUserToken}`
      },
      data: {
        resource: 'documents',
        action: 'read'
      }
    });

    expect(response.status()).toBe(200);
    const result = await response.json();
    expect(result.allowed).toBe(true);
  });

  test('Scenario 6: User attempts unpermitted resource (denied)', async ({ request }) => {
    const response = await request.post(`${API_BASE_URL}/permissions/rbac/check-access`, {
      headers: {
        Authorization: `Bearer ${regularUserToken}`
      },
      data: {
        resource: 'admin-panel',
        action: 'access'
      }
    });

    expect(response.status()).toBe(200);
    const result = await response.json();
    expect(result.allowed).toBe(false);
  });

  test('Scenario 7: DAG closure table updates correctly', async ({ request }) => {
    // Create child organizational unit
    const childResponse = await request.post(`${API_BASE_URL}/permissions/rbac/organizational-units`, {
      headers: {
        Authorization: `Bearer ${adminToken}`
      },
      data: {
        name: 'Frontend Team',
        parent_id: orgUnitId
      }
    });

    expect(childResponse.status()).toBe(201);
    const childOrgUnit = await childResponse.json();

    // Verify closure table entries
    const closureResponse = await request.get(
      `${API_BASE_URL}/permissions/rbac/organizational-units/${childOrgUnit.id}/ancestors`,
      {
        headers: {
          Authorization: `Bearer ${adminToken}`
        }
      }
    );

    expect(closureResponse.ok()).toBeTruthy();
    const ancestors = await closureResponse.json();

    // Should have two entries: self and parent
    expect(ancestors).toHaveLength(2);
    expect(ancestors.some((a: any) => a.ancestor_id === childOrgUnit.id && a.depth === 0)).toBe(true);
    expect(ancestors.some((a: any) => a.ancestor_id === orgUnitId && a.depth === 1)).toBe(true);
  });

  test('Scenario 8: Admin modifies permissions (changes propagate)', async ({ request }) => {
    // Remove a permission
    const response = await request.delete(
      `${API_BASE_URL}/permissions/rbac/roles/${roleId}/permissions`,
      {
        headers: {
          Authorization: `Bearer ${adminToken}`
        },
        data: {
          resource: 'code',
          action: 'update'
        }
      }
    );

    expect(response.status()).toBe(204);

    // Verify user no longer has permission
    const checkResponse = await request.post(`${API_BASE_URL}/permissions/rbac/check-access`, {
      headers: {
        Authorization: `Bearer ${regularUserToken}`
      },
      data: {
        resource: 'code',
        action: 'update'
      }
    });

    const result = await checkResponse.json();
    expect(result.allowed).toBe(false);
  });

  test('Scenario 9: Inherited permissions from parent OU', async ({ request }) => {
    // Create grandchild OU
    const frontendTeamId = orgUnitId; // From previous tests

    const grandchildResponse = await request.post(`${API_BASE_URL}/permissions/rbac/organizational-units`, {
      headers: {
        Authorization: `Bearer ${adminToken}`
      },
      data: {
        name: 'React Team',
        parent_id: frontendTeamId
      }
    });

    const grandchildOrgUnit = await grandchildResponse.json();

    // Assign user to grandchild OU
    await request.post(`${API_BASE_URL}/permissions/rbac/user-assignments`, {
      headers: {
        Authorization: `Bearer ${adminToken}`
      },
      data: {
        userId: regularUserToken,
        orgUnitId: grandchildOrgUnit.id
      }
    });

    // User should inherit permissions from ancestor OUs
    const checkResponse = await request.post(`${API_BASE_URL}/permissions/rbac/check-access`, {
      headers: {
        Authorization: `Bearer ${regularUserToken}`
      },
      data: {
        resource: 'documents',
        action: 'read'
      }
    });

    const result = await checkResponse.json();
    expect(result.allowed).toBe(true);
  });

  test('Scenario 10: Role removal revokes permissions', async ({ request }) => {
    // Remove role assignment
    const response = await request.delete(
      `${API_BASE_URL}/permissions/rbac/role-assignments`,
      {
        headers: {
          Authorization: `Bearer ${adminToken}`
        },
        data: {
          userId: regularUserToken,
          orgUnitId: orgUnitId,
          roleId: roleId
        }
      }
    );

    expect(response.status()).toBe(204);

    // Verify permissions are revoked
    const checkResponse = await request.post(`${API_BASE_URL}/permissions/rbac/check-access`, {
      headers: {
        Authorization: `Bearer ${regularUserToken}`
      },
      data: {
        resource: 'documents',
        action: 'read'
      }
    });

    const result = await checkResponse.json();
    expect(result.allowed).toBe(false);
  });
});
