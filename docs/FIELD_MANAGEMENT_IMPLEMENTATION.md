# Field Management & User Network - Implementation Guide

**Status**: Foundation Complete ✅
**Date**: 2026-01-15
**Author**: Claude Code Assistant

---

## 📋 Executive Summary

This document provides a comprehensive implementation guide for the **Field Management System**, **User Network (MLM)**, and **CMS Admin** features. The database foundation is complete and production-ready.

### ✅ Completed (Phase 1-3)
- ✅ Database schema for Field Types, Field Groups, nested groups
- ✅ Database schema for User Network (MLM sponsor/upline hierarchy)
- ✅ Resource field assignment extended for groups
- ✅ Seed data (address, bank_account, contact_info, persona)
- ✅ Field Types CRUD API (`fieldTypes.ts`)
- ✅ OrgUnits Page ReactFlow fix
- ✅ Field Management in ResourcesPage (Add/Delete fields)

### 🚧 In Progress
- Field Groups CRUD API
- User Network CRUD API
- YAML field definition upload/download
- CMS Admin Remote application
- Form Builder UI
- @reactour/tour integration

---

## 🗄️ Database Schema Overview

### Field Management Tables

```
field_types                    -- Global field library (street, city, iban, etc)
├── id, tenant_id, key
├── display_name, description
├── data_type (string, number, email, date, json)
├── validation_rules (JSONB)
├── is_sensitive, is_system_field
└── category (address, financial, contact, personal)

field_groups                   -- Composite fields (address, bank_account, persona)
├── id, tenant_id, key
├── display_name, description, icon
├── parent_group_id (for nesting)
└── is_system_group

field_group_members            -- Which fields belong to which group
├── field_group_id
├── field_type_id OR child_group_id (either/or)
├── display_order, is_required
└── validation_rules (override)

field_yaml_definitions         -- YAML-based system field management
├── id, tenant_id, name
├── yaml_content (TEXT)
├── parsed_json (JSONB cache)
└── version, uploaded_by

rbac_resource_fields           -- UPDATED: Assignment to resources
├── resource_id
├── field_group_id (NEW)
├── is_group_assignment (NEW)
└── key/display_name (nullable when group)
```

### User Network Tables (MLM)

```
user_network                   -- Sponsor/upline relationships
├── id, tenant_id, user_id
├── sponsor_id (upline)
├── placement_id (binary tree position)
├── level (depth in network)
└── network_position, metadata

user_network_closure           -- Transitive closure for fast queries
├── tenant_id
├── ancestor_id, descendant_id
├── depth
└── path_type (sponsor, placement)

user_connections               -- LinkedIn-like connections (future)
├── id, tenant_id
├── user_id, connected_user_id
├── connection_type (friend, colleague, client)
└── status (pending, accepted, blocked)
```

### Key Features
- ✅ **Nested Groups**: Groups can contain other groups (persona → address + contact_info)
- ✅ **System Fields**: Managed via YAML upload (high permission threshold)
- ✅ **Custom Fields**: User-created fields via UI
- ✅ **Validation Rules**: Per-field and per-group-member overrides
- ✅ **Multi-tenant**: All tables scoped by tenant_id

---

## 🚀 Implementation Roadmap

### Phase 1: Backend APIs (Priority: HIGH)

#### 1.1 Field Groups API
**File**: `/lg-permissions-service/src/routes/fieldGroups.ts`

**Endpoints**:
```typescript
GET    /api/rbac/field-groups                 // List all groups
GET    /api/rbac/field-groups/:id             // Get single group
POST   /api/rbac/field-groups                 // Create group
PUT    /api/rbac/field-groups/:id             // Update group
DELETE /api/rbac/field-groups/:id             // Delete group
GET    /api/rbac/field-groups/:id/members     // Get group members (fields + nested groups)
POST   /api/rbac/field-groups/:id/members     // Add field/group to group
DELETE /api/rbac/field-groups/:id/members/:memberId  // Remove member
PUT    /api/rbac/field-groups/:id/members/order     // Reorder members (drag & drop)
GET    /api/rbac/field-groups/:id/flatten     // Get flattened field list (recursive)
```

**Key Logic**:
```typescript
// Flatten nested groups recursively
async function flattenFieldGroup(groupId: string): Promise<FlatField[]> {
  const members = await getGroupMembers(groupId);
  const fields: FlatField[] = [];

  for (const member of members) {
    if (member.field_type_id) {
      fields.push(member);
    } else if (member.child_group_id) {
      const nested = await flattenFieldGroup(member.child_group_id);
      fields.push(...nested);
    }
  }

  return fields;
}
```

#### 1.2 YAML Field Management API
**File**: `/lg-permissions-service/src/routes/fieldYaml.ts`

**Endpoints**:
```typescript
GET    /api/rbac/field-yaml                   // List YAML definitions
POST   /api/rbac/field-yaml/upload            // Upload YAML file
GET    /api/rbac/field-yaml/:id/download      // Download YAML
POST   /api/rbac/field-yaml/:id/apply         // Apply YAML to create/update fields
DELETE /api/rbac/field-yaml/:id               // Delete definition
```

**YAML Format Example**:
```yaml
# address-fields.yaml
version: "1.0"
category: address
fields:
  - key: street
    display_name: Straße
    data_type: string
    validation:
      required: true
      minLength: 3
  - key: postal_code
    display_name: PLZ
    data_type: string
    validation:
      required: true
      pattern: "^[0-9]{5}$"
groups:
  - key: address
    display_name: Adresse
    icon: map-pin
    members:
      - field: street
        order: 1
        required: true
      - field: city
        order: 2
        required: true
```

**Upload Handler**:
```typescript
import yaml from 'js-yaml';

router.post('/upload', async (req, res) => {
  const { name, yamlContent } = req.body;

  // Parse YAML
  const parsed = yaml.load(yamlContent);

  // Validate schema
  const validated = yamlSchema.parse(parsed);

  // Store in database
  await pool.query(
    `INSERT INTO field_yaml_definitions (tenant_id, name, yaml_content, parsed_json, version)
     VALUES ($1, $2, $3, $4, $5)`,
    [tenantId, name, yamlContent, JSON.stringify(validated), validated.version]
  );

  res.json({ success: true });
});
```

#### 1.3 User Network API
**File**: `/lg-permissions-service/src/routes/userNetwork.ts`

**Endpoints**:
```typescript
GET    /api/rbac/user-network/:userId         // Get user's network info
GET    /api/rbac/user-network/:userId/upline  // Get upline (sponsors)
GET    /api/rbac/user-network/:userId/downline // Get downline (recruits)
POST   /api/rbac/user-network                 // Create network entry (assign sponsor)
PUT    /api/rbac/user-network/:userId         // Update network position
DELETE /api/rbac/user-network/:userId         // Remove from network
GET    /api/rbac/user-network/:userId/tree    // Get full tree (ReactFlow data)
POST   /api/rbac/user-network/rebuild-closure // Rebuild closure table
```

**Tree Data for ReactFlow**:
```typescript
router.get('/:userId/tree', async (req, res) => {
  const { userId } = req.params;
  const { depth = 5, direction = 'both' } = req.query;

  // Get network members via closure table
  const members = await pool.query(`
    SELECT u.id, u.name, u.email, un.level, un.sponsor_id, un.network_position
    FROM user_network_closure unc
    JOIN user_network un ON un.user_id = unc.descendant_id
    JOIN users u ON u.id = un.user_id
    WHERE unc.ancestor_id = $1 AND unc.depth <= $2
  `, [userId, depth]);

  // Convert to ReactFlow nodes/edges
  const nodes = members.rows.map(m => ({
    id: m.id,
    type: 'default',
    data: { label: m.name, level: m.level },
    position: { x: 0, y: 0 }, // Will be layouted by dagre
  }));

  const edges = members.rows
    .filter(m => m.sponsor_id)
    .map(m => ({
      id: `${m.sponsor_id}-${m.id}`,
      source: m.sponsor_id,
      target: m.id,
    }));

  res.json({ success: true, data: { nodes, edges } });
});
```

#### 1.4 Form Builder API (Future)
**File**: `/lg-permissions-service/src/routes/formBuilder.ts`

**Endpoints**:
```typescript
GET    /api/rbac/forms                        // List form definitions
POST   /api/rbac/forms                        // Create form
GET    /api/rbac/forms/:id                    // Get form schema
PUT    /api/rbac/forms/:id                    // Update form
DELETE /api/rbac/forms/:id                    // Delete form
POST   /api/rbac/forms/:id/validate           // Validate form data
```

---

### Phase 2: CMS Admin Remote (Priority: HIGH)

#### 2.1 Create CMS Admin Project

**Structure**:
```
lg-cms-admin/
├── src/
│   ├── pages/
│   │   ├── DashboardPage.tsx             // CMS Overview
│   │   ├── FieldTypesPage.tsx            // Field Library
│   │   ├── FieldGroupsPage.tsx           // Field Groups
│   │   ├── FormBuilderPage.tsx           // Visual Form Builder
│   │   └── YamlEditorPage.tsx            // YAML Upload/Editor
│   ├── components/
│   │   ├── FieldTypeCard.tsx
│   │   ├── FieldGroupEditor.tsx
│   │   ├── FormCanvas.tsx                // Drag & Drop Form Builder
│   │   └── YamlEditor.tsx                // Monaco Editor
│   ├── api/
│   │   └── client.ts                     // API Client
│   ├── App.tsx
│   └── main.tsx
├── vite.config.ts                        // Module Federation
├── package.json
└── Dockerfile

lg-user-network-admin/                    // Optional: Separate remote for network
├── src/
│   ├── pages/
│   │   ├── NetworkViewerPage.tsx         // ReactFlow visualization
│   │   ├── UplineDownlinePage.tsx        // Hierarchical list
│   │   └── NetworkMatrixPage.tsx         // User connections matrix
│   └── ...
```

#### 2.2 Module Federation Config

**lg-admin-shell/vite.config.ts**:
```typescript
remotes: {
  userAdmin: {...},
  permissionsAdmin: {...},
  apiKeysAdmin: {...},
  cmsAdmin: {  // NEW
    external: `Promise.resolve((window.__REMOTE_BASE_URL__ || 'http://localhost:81') + '/admin/cms/' + (window.__DEV_MODE__ ? '' : 'assets/') + 'remoteEntry.js')`,
    externalType: 'promise'
  },
  userNetworkAdmin: {  // NEW (optional)
    external: `Promise.resolve((window.__REMOTE_BASE_URL__ || 'http://localhost:81') + '/admin/network/' + (window.__DEV_MODE__ ? '' : 'assets/') + 'remoteEntry.js')`,
    externalType: 'promise'
  }
}
```

**lg-cms-admin/vite.config.ts**:
```typescript
export default defineConfig({
  base: '/admin/cms/',
  plugins: [
    react(),
    federation({
      name: 'cmsAdmin',
      filename: 'remoteEntry.js',
      exposes: {
        './DashboardPage': './src/pages/DashboardPage.tsx',
        './FieldTypesPage': './src/pages/FieldTypesPage.tsx',
        './FieldGroupsPage': './src/pages/FieldGroupsPage.tsx',
        './FormBuilderPage': './src/pages/FormBuilderPage.tsx',
        './YamlEditorPage': './src/pages/YamlEditorPage.tsx',
      },
      shared: {
        'react': { singleton: true, requiredVersion: '^18.2.0', strictVersion: false },
        'react-dom': { singleton: true, requiredVersion: '^18.2.0', strictVersion: false },
        'react-router-dom': { singleton: true },
        '@tanstack/react-query': { singleton: true },
        'lucide-react': {},
      },
    }),
  ],
  server: {
    port: 3006,
    host: true,
    cors: true,
  },
  preview: {
    port: 3006,
    host: true,
    cors: true,
  },
});
```

#### 2.3 Menu Registry Update

**Add CMS menu items**:
```typescript
// In menu registry or backend
{
  key: 'cms',
  displayName: 'CMS',
  icon: 'file-text',
  path: '/cms',
  children: [
    { key: 'cms-dashboard', displayName: 'Dashboard', path: '/cms/dashboard' },
    { key: 'field-types', displayName: 'Field Library', path: '/cms/field-types' },
    { key: 'field-groups', displayName: 'Field Groups', path: '/cms/field-groups' },
    { key: 'form-builder', displayName: 'Form Builder', path: '/cms/form-builder' },
    { key: 'yaml-editor', displayName: 'YAML Editor', path: '/cms/yaml-editor' },
  ]
},
{
  key: 'user-network',
  displayName: 'User Network',
  icon: 'network',
  path: '/network',
  children: [
    { key: 'network-viewer', displayName: 'Network Viewer', path: '/network/viewer' },
    { key: 'upline-downline', displayName: 'Upline/Downline', path: '/network/upline-downline' },
  ]
}
```

---

### Phase 3: Field Management UI (Priority: HIGH)

#### 3.1 Field Types Page
**File**: `/lg-cms-admin/src/pages/FieldTypesPage.tsx`

**Features**:
- Grid/List view of all field types
- Category filter (address, financial, contact, personal)
- Search by name/key
- Create/Edit/Delete field types
- System field indicator (cannot delete/edit)
- Field type card showing: name, key, data type, validation rules

**UI Layout**:
```tsx
export default function FieldTypesPage() {
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);

  const { data: fieldTypes = [] } = useQuery(['field-types', selectedCategory], () =>
    apiClient.getFieldTypes({ category: selectedCategory !== 'all' ? selectedCategory : undefined })
  );

  const { data: categories = [] } = useQuery(['field-categories'], () =>
    apiClient.getFieldCategories()
  );

  return (
    <div className="h-full flex flex-col">
      {/* Header */}
      <div className="p-6 border-b bg-white">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold flex items-center gap-2">
              <Database size={28} />
              Field Library
            </h1>
            <p className="text-gray-600">Global reusable field definitions</p>
          </div>
          <button onClick={() => setIsCreateModalOpen(true)}>
            <Plus size={18} />
            Create Field Type
          </button>
        </div>

        {/* Category Filters */}
        <div className="flex gap-2 mt-4">
          <button onClick={() => setSelectedCategory('all')}>All</button>
          {categories.map(cat => (
            <button key={cat.category} onClick={() => setSelectedCategory(cat.category)}>
              {cat.category} ({cat.field_count})
            </button>
          ))}
        </div>
      </div>

      {/* Field Type Grid */}
      <div className="flex-1 overflow-auto p-6">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {fieldTypes.map(field => (
            <FieldTypeCard key={field.id} field={field} />
          ))}
        </div>
      </div>

      {/* Create Modal */}
      <FieldTypeModal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
      />
    </div>
  );
}
```

#### 3.2 Field Groups Page
**File**: `/lg-cms-admin/src/pages/FieldGroupsPage.tsx`

**Features**:
- List of all field groups
- Visual group preview (shows all members)
- Nested group support (show child groups)
- Drag & drop reordering of group members
- Add field/group to group
- Remove member from group
- Flatten button (show all fields recursively)

**Group Editor**:
```tsx
function FieldGroupEditor({ groupId }: { groupId: string }) {
  const { data: group } = useQuery(['field-group', groupId], () =>
    apiClient.getFieldGroup(groupId)
  );

  const { data: members = [] } = useQuery(['field-group-members', groupId], () =>
    apiClient.getFieldGroupMembers(groupId)
  );

  const { data: availableFields } = useQuery(['field-types'], () =>
    apiClient.getFieldTypes()
  );

  const { data: availableGroups } = useQuery(['field-groups'], () =>
    apiClient.getFieldGroups()
  );

  return (
    <div className="grid grid-cols-2 gap-6">
      {/* Left: Available Fields/Groups */}
      <div>
        <h3>Available Fields</h3>
        <DragDropContext>
          {availableFields.map(field => (
            <Draggable key={field.id} draggableId={field.id}>
              <FieldTypeCard field={field} />
            </Draggable>
          ))}
        </DragDropContext>

        <h3>Available Groups</h3>
        {availableGroups.map(group => (
          <FieldGroupCard key={group.id} group={group} />
        ))}
      </div>

      {/* Right: Current Group Members */}
      <div>
        <h3>{group.display_name} Members</h3>
        <Droppable droppableId="group-members">
          {members.map((member, index) => (
            <Draggable key={member.id} draggableId={member.id} index={index}>
              {member.field_type_id ? (
                <FieldMemberCard member={member} />
              ) : (
                <NestedGroupCard member={member} />
              )}
            </Draggable>
          ))}
        </Droppable>

        <button onClick={handleFlatten}>
          <List size={16} />
          Flatten (show all fields)
        </button>
      </div>
    </div>
  );
}
```

#### 3.3 YAML Editor Page
**File**: `/lg-cms-admin/src/pages/YamlEditorPage.tsx`

**Features**:
- Monaco Editor for YAML editing
- Upload YAML file
- Download existing definitions
- Apply YAML to create/update fields
- Validation before apply
- Diff view (show what will change)

**Implementation**:
```tsx
import Editor from '@monaco-editor/react';

export default function YamlEditorPage() {
  const [yamlContent, setYamlContent] = useState('');
  const [parsedPreview, setParsedPreview] = useState(null);

  const handleUpload = async () => {
    const file = await selectFile();
    const content = await file.text();
    setYamlContent(content);

    // Parse and preview
    const parsed = yaml.load(content);
    setParsedPreview(parsed);
  };

  const handleApply = async () => {
    await apiClient.uploadFieldYaml({
      name: 'custom-fields',
      yamlContent,
    });

    // Apply to create/update fields
    await apiClient.applyFieldYaml(uploadedId);
  };

  return (
    <div className="grid grid-cols-2 h-full">
      {/* Left: YAML Editor */}
      <div>
        <Editor
          height="100%"
          language="yaml"
          value={yamlContent}
          onChange={(value) => setYamlContent(value || '')}
          theme="vs-dark"
        />
      </div>

      {/* Right: Preview */}
      <div>
        <h3>Preview</h3>
        {parsedPreview && (
          <div>
            <h4>Fields ({parsedPreview.fields.length})</h4>
            {parsedPreview.fields.map(f => (
              <div key={f.key}>{f.display_name} ({f.data_type})</div>
            ))}

            <h4>Groups ({parsedPreview.groups.length})</h4>
            {parsedPreview.groups.map(g => (
              <div key={g.key}>{g.display_name}</div>
            ))}
          </div>
        )}

        <button onClick={handleApply}>Apply Changes</button>
      </div>
    </div>
  );
}
```

---

### Phase 4: Form Builder UI (Priority: MEDIUM)

#### 4.1 Form Canvas
**File**: `/lg-cms-admin/src/pages/FormBuilderPage.tsx`

**Features**:
- Drag & drop fields from library onto canvas
- Drop field groups (auto-expand to all fields)
- Visual form preview
- Form schema JSON export
- Save form definitions
- Section/fieldset organization

**Implementation**:
```tsx
import { DndContext, DragOverlay, useDroppable } from '@dnd-kit/core';

export default function FormBuilderPage() {
  const [formSections, setFormSections] = useState([
    { title: 'Personal Info', fields: [] },
    { title: 'Address', fields: [] },
  ]);

  const handleDrop = (sectionIndex, fieldOrGroup) => {
    if (fieldOrGroup.type === 'group') {
      // Flatten group and add all fields
      const fields = await apiClient.flattenFieldGroup(fieldOrGroup.id);
      addFieldsToSection(sectionIndex, fields);
    } else {
      addFieldToSection(sectionIndex, fieldOrGroup);
    }
  };

  return (
    <DndContext onDragEnd={handleDragEnd}>
      <div className="grid grid-cols-3 gap-4">
        {/* Left: Field Library */}
        <FieldLibrarySidebar />

        {/* Center: Form Canvas */}
        <div className="col-span-2">
          {formSections.map((section, index) => (
            <FormSection key={index} section={section} onDrop={(item) => handleDrop(index, item)} />
          ))}
        </div>

        {/* Right: Properties Panel */}
        <PropertiesPanel selectedField={selectedField} />
      </div>
    </DndContext>
  );
}
```

#### 4.2 Form Renderer Component
**File**: `/lg-cms-admin/src/components/FormRenderer.tsx`

**Usage**:
```tsx
<FormRenderer
  formSchema={formSchema}
  resource="users"
  userId={currentUser.id}
  onlyAllowedFields={true}  // Filter by RBAC permissions
  onSubmit={handleSubmit}
/>
```

**Implementation**:
```tsx
export function FormRenderer({ formSchema, resource, userId, onlyAllowedFields, onSubmit }) {
  const { data: permissions } = useQuery(['user-permissions', userId], () =>
    apiClient.getEffectivePermissions(userId)
  );

  const filterFields = (fields) => {
    if (!onlyAllowedFields) return fields;

    return fields.filter(field => {
      const permKey = `${resource}:read:${field.key}`;
      return permissions.some(p => p.permissionKey === permKey && p.effect === 'allow');
    });
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      {formSchema.sections.map(section => (
        <fieldset key={section.title}>
          <legend>{section.title}</legend>

          {section.field_group ? (
            <FieldGroup group={section.field_group} fields={filterFields(section.fields)} />
          ) : (
            section.fields.map(field => <FieldInput key={field.key} field={field} />)
          )}
        </fieldset>
      ))}

      <button type="submit">Submit</button>
    </form>
  );
}
```

---

### Phase 5: User Network UI (Priority: MEDIUM)

#### 5.1 Network Viewer Page
**File**: `/lg-user-network-admin/src/pages/NetworkViewerPage.tsx`

**Features**:
- ReactFlow visualization of network tree
- Toggle between sponsor tree / placement tree
- Depth filter (5, 10, unlimited levels)
- Search user in network
- Click node to see user details
- Stats: Total downline, active members, levels

**Implementation**:
```tsx
import { ReactFlow, Background, Controls, MarkerType } from '@xyflow/react';
import dagre from 'dagre';

export default function NetworkViewerPage() {
  const [selectedUserId, setSelectedUserId] = useState(null);
  const [depth, setDepth] = useState(5);
  const [pathType, setPathType] = useState('sponsor'); // sponsor or placement

  const { data: networkData } = useQuery(
    ['user-network-tree', selectedUserId, depth, pathType],
    () => apiClient.getUserNetworkTree(selectedUserId, { depth, pathType })
  );

  const { nodes, edges } = useMemo(() => {
    if (!networkData) return { nodes: [], edges: [] };
    return layoutTree(networkData.nodes, networkData.edges);
  }, [networkData]);

  return (
    <div className="h-screen flex flex-col">
      <div className="p-4 border-b flex items-center justify-between">
        <h1>Network Viewer</h1>

        <div className="flex gap-4">
          <select value={pathType} onChange={(e) => setPathType(e.target.value)}>
            <option value="sponsor">Sponsor Tree</option>
            <option value="placement">Placement Tree</option>
          </select>

          <select value={depth} onChange={(e) => setDepth(Number(e.target.value))}>
            <option value={5}>5 Levels</option>
            <option value={10}>10 Levels</option>
            <option value={100}>Unlimited</option>
          </select>

          <UserSearchInput onSelect={setSelectedUserId} />
        </div>
      </div>

      <div className="flex-1">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodeClick={(_, node) => setSelectedUser(node.data)}
          fitView
        >
          <Background />
          <Controls />
          <Panel position="top-right">
            <NetworkStats networkData={networkData} />
          </Panel>
        </ReactFlow>
      </div>
    </div>
  );
}
```

#### 5.2 Upline/Downline Page
**File**: `/lg-user-network-admin/src/pages/UplineDownlinePage.tsx`

**Features**:
- Hierarchical list view (tree structure)
- Toggle expand/collapse levels
- Show upline chain (breadcrumb to root)
- Show downline (collapsible tree)
- User stats per entry (level, recruits, sales)
- Export to CSV

**Implementation**:
```tsx
export default function UplineDownlinePage() {
  const { data: upline } = useQuery(['user-upline', userId], () =>
    apiClient.getUserUpline(userId)
  );

  const { data: downline } = useQuery(['user-downline', userId], () =>
    apiClient.getUserDownline(userId)
  );

  return (
    <div className="grid grid-cols-2 gap-6">
      {/* Left: Upline Chain */}
      <div>
        <h2>Upline Chain</h2>
        <ol className="breadcrumb">
          {upline.map(user => (
            <li key={user.id}>
              <UserCard user={user} />
            </li>
          ))}
        </ol>
      </div>

      {/* Right: Downline Tree */}
      <div>
        <h2>Downline ({downline.length})</h2>
        <Tree data={downline} renderNode={(node) => <UserCard user={node} />} />
      </div>
    </div>
  );
}
```

---

### Phase 6: @reactour/tour Integration (Priority: LOW)

#### 6.1 Install Dependencies

```bash
./dev.sh npm-in lg-admin-shell install @reactour/tour
./dev.sh npm-in lg-user-admin install @reactour/tour
./dev.sh npm-in lg-permissions-admin install @reactour/tour
./dev.sh npm-in lg-api-keys-admin install @reactour/tour
./dev.sh npm-in lg-cms-admin install @reactour/tour  # once created
```

#### 6.2 Tour Provider Setup

**File**: `/lg-admin-shell/src/App.tsx`

```tsx
import { TourProvider } from '@reactour/tour';

function App() {
  return (
    <TourProvider
      steps={[
        {
          selector: '[data-tour="navigation"]',
          content: 'Welcome! This is the main navigation menu.',
        },
        {
          selector: '[data-tour="user-menu"]',
          content: 'Access your profile and settings here.',
        },
      ]}
      styles={{
        popover: (base) => ({
          ...base,
          borderRadius: 8,
        }),
      }}
    >
      <QueryClientProvider client={queryClient}>
        <RouterProvider router={router} />
      </QueryClientProvider>
    </TourProvider>
  );
}
```

#### 6.3 Tour Definitions per Page

**File**: `/lg-permissions-admin/src/tours/orgUnitsTour.ts`

```typescript
export const orgUnitsTour = [
  {
    selector: '[data-tour="ou-hierarchy"]',
    content: 'This is the organizational hierarchy. Click on a unit to see details.',
  },
  {
    selector: '[data-tour="create-ou"]',
    content: 'Create new organizational units here.',
  },
  {
    selector: '[data-tour="ou-legend"]',
    content: 'Different colors represent different hierarchy levels.',
  },
];
```

**Usage in Component**:
```tsx
import { useTour } from '@reactour/tour';

export default function OrgUnitsPage() {
  const { setIsOpen, setSteps } = useTour();

  useEffect(() => {
    // Set page-specific tour steps
    setSteps(orgUnitsTour);

    // Check if user wants tour (localStorage)
    if (!localStorage.getItem('tour-org-units-completed')) {
      setIsOpen(true);
    }
  }, []);

  return (
    <div>
      <button onClick={() => setIsOpen(true)}>
        <HelpCircle /> Start Tour
      </button>

      <div data-tour="ou-hierarchy">
        <ReactFlow ... />
      </div>

      <button data-tour="create-ou" onClick={...}>
        Create OU
      </button>
    </div>
  );
}
```

#### 6.4 Global Tour Configuration

**File**: `/lg-admin-shell/src/config/tours.ts`

```typescript
export const tourConfig = {
  // Welcome tour (shown on first login)
  welcome: [
    { selector: '[data-tour="dashboard"]', content: 'Welcome to LicenseGuard Admin!' },
    { selector: '[data-tour="navigation"]', content: 'Navigate between modules here.' },
    { selector: '[data-tour="user-menu"]', content: 'Access your settings.' },
  ],

  // Feature-specific tours
  permissions: [...],
  orgUnits: [...],
  fieldManagement: [...],
  formBuilder: [...],
  userNetwork: [...],
};

// Tour completion tracking
export function markTourComplete(tourId: string) {
  localStorage.setItem(`tour-${tourId}-completed`, 'true');
  localStorage.setItem(`tour-${tourId}-completed-at`, new Date().toISOString());
}

export function isTourCompleted(tourId: string): boolean {
  return localStorage.getItem(`tour-${tourId}-completed`) === 'true';
}

export function resetAllTours() {
  Object.keys(localStorage)
    .filter(key => key.startsWith('tour-'))
    .forEach(key => localStorage.removeItem(key));
}
```

#### 6.5 Tour UI Enhancements

**Add Tour Trigger Buttons**:
```tsx
// In page header or help menu
<DropdownMenu>
  <DropdownMenuItem onClick={() => setIsOpen(true)}>
    <HelpCircle size={16} />
    Start Page Tour
  </DropdownMenuItem>
  <DropdownMenuItem onClick={() => startWelcomeTour()}>
    <Play size={16} />
    Welcome Tour
  </DropdownMenuItem>
  <DropdownMenuItem onClick={resetAllTours}>
    <RotateCcw size={16} />
    Reset All Tours
  </DropdownMenuItem>
</DropdownMenu>
```

---

## 📦 Package Dependencies

### Backend (lg-permissions-service)
```json
{
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "zod": "^3.22.4",
    "js-yaml": "^4.1.0"
  },
  "devDependencies": {
    "@types/js-yaml": "^4.0.9"
  }
}
```

### Frontend (lg-cms-admin)
```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.21.1",
    "@tanstack/react-query": "^5.17.0",
    "lucide-react": "^0.303.0",
    "@monaco-editor/react": "^4.6.0",
    "js-yaml": "^4.1.0",
    "@dnd-kit/core": "^6.1.0",
    "@dnd-kit/sortable": "^8.0.0",
    "@xyflow/react": "^12.3.5",
    "dagre": "^0.8.5",
    "@reactour/tour": "^3.7.0"
  }
}
```

---

## 🔄 Migration Path for Existing Data

### Migrating rbac_resource_fields to Field Groups

**Current State**: Resources have individual fields with key/display_name directly in `rbac_resource_fields`

**Target State**: Resources reference field_groups, which reference field_types

**Migration Script**:
```sql
-- Step 1: Create field types from existing resource fields
INSERT INTO field_types (tenant_id, key, display_name, data_type, category, is_system_field)
SELECT DISTINCT
  '00000000-0000-0000-0000-000000000000' as tenant_id,
  rf.key,
  rf.display_name,
  COALESCE(rf.field_type, 'string') as data_type,
  'custom' as category,
  false as is_system_field
FROM rbac_resource_fields rf
WHERE rf.key IS NOT NULL AND rf.field_group_id IS NULL
ON CONFLICT (tenant_id, key) DO NOTHING;

-- Step 2: Create a field group for each resource (if desired)
INSERT INTO field_groups (tenant_id, key, display_name)
SELECT
  '00000000-0000-0000-0000-000000000000' as tenant_id,
  r.key || '_fields' as key,
  r.display_name || ' Fields' as display_name
FROM rbac_resources r;

-- Step 3: Link existing fields to resource groups
INSERT INTO field_group_members (field_group_id, field_type_id, display_order)
SELECT
  fg.id as field_group_id,
  ft.id as field_type_id,
  ROW_NUMBER() OVER (PARTITION BY fg.id ORDER BY rf.key) as display_order
FROM rbac_resource_fields rf
JOIN rbac_resources r ON r.id = rf.resource_id
JOIN field_groups fg ON fg.key = r.key || '_fields'
JOIN field_types ft ON ft.key = rf.key
WHERE rf.key IS NOT NULL;

-- Step 4: Update resource_fields to reference groups instead
UPDATE rbac_resource_fields rf
SET
  field_group_id = fg.id,
  is_group_assignment = true,
  key = NULL,
  display_name = NULL
FROM rbac_resources r
JOIN field_groups fg ON fg.key = r.key || '_fields'
WHERE rf.resource_id = r.id AND rf.field_group_id IS NULL;
```

---

## 🧪 Testing Strategy

### Unit Tests
```typescript
// fieldTypes.test.ts
describe('Field Types API', () => {
  it('should create field type', async () => {
    const result = await request(app)
      .post('/api/rbac/field-types')
      .send({
        key: 'test_field',
        displayName: 'Test Field',
        dataType: 'string',
      });

    expect(result.status).toBe(201);
    expect(result.body.data.key).toBe('test_field');
  });

  it('should not allow duplicate keys', async () => {
    // ... test duplicate prevention
  });

  it('should not allow editing system fields', async () => {
    // ... test system field protection
  });
});
```

### Integration Tests
```typescript
// fieldGroups.test.ts
describe('Field Groups Integration', () => {
  it('should flatten nested groups correctly', async () => {
    // Create persona group with nested address + contact_info
    const fields = await flattenFieldGroup(personaGroupId);

    expect(fields).toContainEqual(
      expect.objectContaining({ key: 'first_name' })
    );
    expect(fields).toContainEqual(
      expect.objectContaining({ key: 'street' }) // from nested address
    );
    expect(fields).toContainEqual(
      expect.objectContaining({ key: 'phone' }) // from nested contact_info
    );
  });
});
```

---

## 📊 Performance Considerations

### Database Indexes (Already Applied)
```sql
CREATE INDEX idx_field_types_tenant ON field_types(tenant_id);
CREATE INDEX idx_field_types_category ON field_types(category);
CREATE INDEX idx_field_group_members_group ON field_group_members(field_group_id);
CREATE INDEX idx_user_network_closure_ancestor ON user_network_closure(ancestor_id);
CREATE INDEX idx_user_network_closure_descendant ON user_network_closure(descendant_id);
```

### Caching Strategy
- **Field Types**: Cache for 1 hour (rarely change)
- **Field Groups**: Cache for 30 minutes
- **User Network Closure**: Rebuild on network changes only
- **Flattened Groups**: Memoize in frontend (React.useMemo)

### Query Optimization
```typescript
// Instead of N+1 queries for group members
const members = await pool.query(`
  SELECT
    fgm.*,
    ft.key as field_key, ft.display_name as field_display_name,
    fg.key as group_key, fg.display_name as group_display_name
  FROM field_group_members fgm
  LEFT JOIN field_types ft ON ft.id = fgm.field_type_id
  LEFT JOIN field_groups fg ON fg.id = fgm.child_group_id
  WHERE fgm.field_group_id = $1
  ORDER BY fgm.display_order
`, [groupId]);
```

---

## 🚨 Security Considerations

### System Field Protection
- System fields (`is_system_field = true`) cannot be modified via UI
- Only YAML upload with high permission threshold can modify
- RBAC check: `system_fields:manage` permission required

### YAML Upload Permission
```typescript
// Middleware for YAML upload
async function requireSystemFieldsPermission(req, res, next) {
  const userId = req.userId;
  const hasPermission = await checkPermission(userId, 'system_fields:manage');

  if (!hasPermission) {
    return res.status(403).json({
      error: 'Insufficient permissions to manage system fields',
    });
  }

  next();
}

router.post('/upload', requireSystemFieldsPermission, async (req, res) => {
  // ... YAML upload logic
});
```

### Tenant Isolation
- All queries must include `WHERE tenant_id = $1`
- Extract tenant_id from JWT token
- Never allow cross-tenant field access

### Validation
- Validate YAML schema before applying
- Prevent circular nested groups
- Validate field data types match database constraints
- Sanitize user input (XSS prevention)

---

## 📚 Additional Resources

### YAML Field Definition Schema
```yaml
# schema.yaml - Complete field definition format
version: "1.0"
category: address  # address, financial, contact, personal, custom

fields:
  - key: street           # Required: unique identifier (lowercase, no spaces)
    display_name: Straße  # Required: human-readable name
    data_type: string     # Required: string|number|boolean|email|password|date|json|text
    description: Street address line 1  # Optional
    placeholder: Musterstraße 123       # Optional
    help_text: Enter your street name and number  # Optional
    is_sensitive: false   # Optional: default false
    validation:           # Optional validation rules
      required: true
      minLength: 3
      maxLength: 255
      pattern: "^[A-Za-z0-9\\s]+$"

groups:
  - key: address
    display_name: Adresse
    description: Full postal address
    icon: map-pin  # Lucide icon name
    members:
      - field: street        # Reference to field key
        order: 1
        required: true
        validation:          # Optional: override field validation
          minLength: 5
      - field: city
        order: 2
        required: true
      - group: country_info  # Reference to nested group
        order: 3
        required: false
```

### API Client Usage Examples
```typescript
// Fetch all field types
const fieldTypes = await apiClient.getFieldTypes();

// Create field type
await apiClient.createFieldType({
  key: 'custom_field',
  displayName: 'Custom Field',
  dataType: 'string',
  category: 'custom',
});

// Get flattened group (recursive)
const fields = await apiClient.flattenFieldGroup(groupId);

// Upload YAML
const file = await selectFile();
const content = await file.text();
await apiClient.uploadFieldYaml({ name: 'custom', yamlContent: content });

// Get user network tree
const { nodes, edges } = await apiClient.getUserNetworkTree(userId, { depth: 10 });
```

---

## ✅ Acceptance Criteria

### Field Management System
- [ ] Field Types CRUD works in UI
- [ ] Field Groups CRUD works in UI
- [ ] Nested groups render correctly
- [ ] YAML upload/download works
- [ ] System field protection enforced
- [ ] Field categories filter works
- [ ] Drag & drop reordering works

### Form Builder
- [ ] Drag field from library onto canvas
- [ ] Drop field group expands to fields
- [ ] Form preview renders correctly
- [ ] Form schema export works
- [ ] Permission-based field filtering works

### User Network
- [ ] Network tree visualizes correctly
- [ ] Upline/downline queries work
- [ ] Closure table rebuilds correctly
- [ ] Depth filtering works
- [ ] Network stats calculate correctly

### @reactour/tour
- [ ] Tours load on first page visit
- [ ] Tours can be manually triggered
- [ ] Tour completion tracked
- [ ] Reset tours works
- [ ] All major pages have tours

---

## 🎯 Next Steps

1. **Immediate**: Complete Field Groups API (`fieldGroups.ts`)
2. **Short-term**: Create CMS Admin remote + basic UI
3. **Medium-term**: Implement Form Builder
4. **Long-term**: User Network visualization + Tours

---

**Document Version**: 1.0
**Last Updated**: 2026-01-15
**Status**: Ready for Implementation ✅
