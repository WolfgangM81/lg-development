#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Output files
OUTPUT_JSON=".dependency-graph.json"
OUTPUT_TXT=".migration-order.txt"

# Base directory
BASE_DIR="/Users/wolfgang/Projects"
PROJECTS=(
    "lg-admin"
    "lg-admin-ui"
    "lg-menu-registry"
    "lg-management"
    "lg-user-service"
    "lg-permissions-service"
    "lg-api-keys-service"
    "lg-tour-service"
    "lg-platform"
    "lg-e2e-tests"
)

# Temp files for data storage (macOS bash doesn't support associative arrays)
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo -e "${BLUE}=== LicenseGuard Dependency Analyzer ===${NC}"
echo ""

# Function to determine project type
get_project_type() {
    local project=$1
    local project_path="$BASE_DIR/$project"
    local pkg_json="$project_path/package.json"
    
    # Check if it's infrastructure (docker-compose in root)
    if [ -f "$project_path/docker-compose.yml" ]; then
        echo "infrastructure"
        return
    fi
    
    if [ ! -f "$pkg_json" ]; then
        echo "unknown"
        return
    fi
    
    # Check if it's a Next.js project
    if grep -q '"next"' "$pkg_json" 2>/dev/null; then
        echo "nextjs"
        return
    fi
    
    # Check if it's a library (has "types" or "module" field)
    if grep -q '"types":' "$pkg_json" 2>/dev/null || grep -q '"module":' "$pkg_json" 2>/dev/null; then
        echo "library"
        return
    fi
    
    # Check if it's a backend service (has express/fastify/koa)
    if grep -q '"express"\|"fastify"\|"koa"' "$pkg_json" 2>/dev/null; then
        echo "backend"
        return
    fi
    
    # Check if it's a frontend (has react/vue/angular)
    if grep -q '"react"\|"vue"\|"@angular"' "$pkg_json" 2>/dev/null; then
        echo "frontend"
        return
    fi
    
    # Check if it's a monorepo (turborepo/pnpm workspace)
    if grep -q '"turbo"\|"workspaces"' "$pkg_json" 2>/dev/null || [ -f "$project_path/pnpm-workspace.yaml" ]; then
        echo "monorepo"
        return
    fi
    
    echo "other"
}

# Function to extract dependencies
get_dependencies() {
    local project=$1
    local pkg_json="$BASE_DIR/$project/package.json"
    
    if [ ! -f "$pkg_json" ]; then
        echo "[]"
        return
    fi
    
    # Extract @apikeys/* dependencies and map them to lg-* names
    local deps=$(node -e "
        try {
            const pkg = require('$pkg_json');
            const allDeps = { ...pkg.dependencies, ...pkg.devDependencies };
            
            // Map @apikeys/* to lg-* names
            const nameMap = {
                '@apikeys/admin-ui': 'lg-admin-ui',
                '@apikeys/menu-registry': 'lg-menu-registry'
            };
            
            const lgDeps = Object.keys(allDeps)
                .filter(d => d.startsWith('@apikeys/') || d.startsWith('lg-'))
                .map(d => nameMap[d] || d);
            
            console.log(JSON.stringify(lgDeps));
        } catch(e) {
            console.log('[]');
        }
    " 2>/dev/null)
    
    echo "$deps"
}

# Phase 1: Scan all projects
echo -e "${YELLOW}Phase 1: Scanning projects...${NC}"
for project in "${PROJECTS[@]}"; do
    project_path="$BASE_DIR/$project"
    
    if [ ! -d "$project_path" ]; then
        echo -e "  ${RED}✗${NC} $project (not found)"
        continue
    fi
    
    echo -e "  ${GREEN}✓${NC} $project"
    
    # Determine type
    type=$(get_project_type "$project")
    echo "$type" > "$TMP_DIR/${project}.type"
    
    # Get dependencies
    deps=$(get_dependencies "$project")
    echo "$deps" > "$TMP_DIR/${project}.deps"
    
    # Initialize consumers array
    echo "[]" > "$TMP_DIR/${project}.consumers"
done

echo ""

# Phase 2: Build consumer relationships
echo -e "${YELLOW}Phase 2: Building dependency graph...${NC}"
for project in "${PROJECTS[@]}"; do
    deps_file="$TMP_DIR/${project}.deps"
    if [ ! -f "$deps_file" ]; then
        continue
    fi
    
    # Parse dependencies and add to consumers
    deps_array=$(cat "$deps_file" | node -e "
        let input = '';
        process.stdin.on('data', chunk => input += chunk);
        process.stdin.on('end', () => {
            try {
                const deps = JSON.parse(input);
                deps.forEach(d => console.log(d));
            } catch(e) {}
        });
    " 2>/dev/null)
    
    while IFS= read -r dep; do
        if [ -n "$dep" ]; then
            # Add current project to dep's consumers
            consumer_file="$TMP_DIR/${dep}.consumers"
            if [ -f "$consumer_file" ]; then
                current_consumers=$(cat "$consumer_file")
                updated=$(echo "$current_consumers" | node -e "
                    let input = '';
                    process.stdin.on('data', chunk => input += chunk);
                    process.stdin.on('end', () => {
                        try {
                            const arr = JSON.parse(input);
                            arr.push('$project');
                            console.log(JSON.stringify(arr));
                        } catch(e) {
                            console.log('[\"$project\"]');
                        }
                    });
                " 2>/dev/null)
                echo "$updated" > "$consumer_file"
            fi
        fi
    done <<< "$deps_array"
done

echo -e "  ${GREEN}✓${NC} Consumer relationships built"
echo ""

# Phase 3: Generate JSON output
echo -e "${YELLOW}Phase 3: Generating $OUTPUT_JSON...${NC}"

# Build JSON from temp files
TMP_DATA_DIR="$TMP_DIR" node > "$OUTPUT_JSON" << 'EOF_NODE'
const fs = require('fs');
const path = require('path');

const tmpDir = process.env.TMP_DATA_DIR;
const files = fs.readdirSync(tmpDir);

const projects = {};
files.forEach(file => {
    const match = file.match(/^(.+)\.(type|deps|consumers)$/);
    if (match) {
        const [, project, dataType] = match;
        if (!projects[project]) projects[project] = {};
        
        const content = fs.readFileSync(path.join(tmpDir, file), 'utf8').trim();
        
        if (dataType === 'type') {
            projects[project].type = content;
        } else if (dataType === 'deps' || dataType === 'consumers') {
            try {
                projects[project][dataType] = JSON.parse(content);
            } catch(e) {
                projects[project][dataType] = [];
            }
        }
    }
});

const output = {
    libraries: {},
    services: {},
    frontends: {},
    infrastructure: {},
    monorepos: {},
    other: {}
};

for (const [project, data] of Object.entries(projects)) {
    const type = data.type || 'other';
    const deps = data.deps || [];
    const consumers = data.consumers || [];
    
    const entry = {
        type: type === 'library' ? 'npm-package' : type,
        dependsOn: deps,
        consumers: consumers
    };
    
    if (type === 'library') {
        output.libraries[project] = entry;
    } else if (type === 'backend') {
        output.services[project] = entry;
    } else if (type === 'frontend' || type === 'nextjs') {
        output.frontends[project] = entry;
    } else if (type === 'infrastructure') {
        output.infrastructure[project] = entry;
    } else if (type === 'monorepo') {
        output.monorepos[project] = entry;
    } else {
        output.other[project] = entry;
    }
}

console.log(JSON.stringify(output, null, 2));
EOF_NODE

echo -e "  ${GREEN}✓${NC} Generated $OUTPUT_JSON"
echo ""

# Phase 4: Generate migration order
echo -e "${YELLOW}Phase 4: Generating $OUTPUT_TXT...${NC}"

node > "$OUTPUT_TXT" << 'EOF_MIGRATION'
const fs = require('fs');
const graph = JSON.parse(fs.readFileSync('.dependency-graph.json', 'utf8'));

// Flatten all projects
const allProjects = {};
['libraries', 'services', 'frontends', 'infrastructure', 'other'].forEach(category => {
    Object.entries(graph[category]).forEach(([name, data]) => {
        allProjects[name] = data.dependsOn;
    });
});

// Topological sort with levels
const levels = {};
const processed = new Set();

function getLevel(project) {
    if (levels[project] !== undefined) return levels[project];
    if (!allProjects[project]) return 0;
    
    const deps = allProjects[project];
    if (deps.length === 0) {
        levels[project] = 0;
        return 0;
    }
    
    const maxDepLevel = Math.max(...deps.map(dep => getLevel(dep)));
    levels[project] = maxDepLevel + 1;
    return levels[project];
}

// Calculate levels
Object.keys(allProjects).forEach(project => getLevel(project));

// Group by level
const levelGroups = {};
Object.entries(levels).forEach(([project, level]) => {
    if (!levelGroups[level]) levelGroups[level] = [];
    levelGroups[level].push(project);
});

// Output
console.log('=== Migration Order (Topological Sort) ===\n');
console.log('Lower levels can be migrated in parallel.');
console.log('Each level depends only on previous levels.\n');

const sortedLevels = Object.keys(levelGroups).sort((a, b) => parseInt(a) - parseInt(b));
sortedLevels.forEach(level => {
    const projects = levelGroups[level].sort();
    console.log(`Level ${level}: (${projects.length} projects)`);
    projects.forEach(p => {
        const deps = allProjects[p];
        if (deps.length > 0) {
            console.log(`  - ${p} (depends on: ${deps.join(', ')})`);
        } else {
            console.log(`  - ${p} (no dependencies)`);
        }
    });
    console.log('');
});

console.log('=== Recommended Migration Strategy ===\n');
console.log('1. Level 0: Core libraries (parallel safe)');
console.log('2. Level 1: Services depending on Level 0 (parallel safe)');
console.log('3. Level 2+: Higher-level services and frontends\n');
EOF_MIGRATION

echo -e "  ${GREEN}✓${NC} Generated $OUTPUT_TXT"
echo ""

# Summary
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "Generated files:"
echo -e "  - ${GREEN}$OUTPUT_JSON${NC} (dependency graph)"
echo -e "  - ${GREEN}$OUTPUT_TXT${NC} (migration order)"
echo ""
echo -e "View results:"
echo -e "  ${YELLOW}cat $OUTPUT_JSON${NC}"
echo -e "  ${YELLOW}cat $OUTPUT_TXT${NC}"
