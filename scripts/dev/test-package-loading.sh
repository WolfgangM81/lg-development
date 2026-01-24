#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "🧪 Testing Package Loading in Shared Volume"
echo ""

docker run --rm -v lg-development_lg-packages-dist:/workspace/packages node:20-alpine sh -c '
echo "✅ Test 1: Direct path require (menu-registry)"
node -e "
const pkg = require(\"/workspace/packages/menu-registry/index.js\");
console.log(\"   Exports:\", Object.keys(pkg).join(\", \"));
console.log(\"   fetchMenuItems:\", typeof pkg.fetchMenuItems);
" || exit 1

echo ""
echo "✅ Test 2: Direct path require (types)"
node -e "
const pkg = require(\"/workspace/packages/types/index.js\");
console.log(\"   Exports:\", Object.keys(pkg).join(\", \"));
" || exit 1

echo ""
echo "✅ Test 3: Direct path require (backend-common)"
node -e "
const pkg = require(\"/workspace/packages/backend-common/index.js\");
console.log(\"   Exports:\", Object.keys(pkg).join(\", \"));
console.log(\"   createLogger:\", typeof pkg.createLogger);
console.log(\"   AppError:\", typeof pkg.AppError);
" || exit 1

echo ""
echo "✅ Test 4: Scoped package name resolution"
node -e "
const fs = require(\"fs\");
fs.mkdirSync(\"/tmp/node_modules/@wolfgangm81\", { recursive: true });
fs.symlinkSync(\"/workspace/packages/menu-registry\", \"/tmp/node_modules/@wolfgangm81/menu-registry\");
process.env.NODE_PATH = \"/tmp/node_modules\";
require(\"module\").Module._initPaths();
const pkg = require(\"@wolfgangm81/menu-registry\");
console.log(\"   Package loaded via scoped name!\");
console.log(\"   Has fetchMenuItems:\", typeof pkg.fetchMenuItems === \"function\" ? \"✅\" : \"❌\");
" || exit 1

echo ""
echo "✅ Test 5: Check package.json type field"
node -e "
const pkg = require(\"/workspace/packages/menu-registry/package.json\");
if (pkg.type === \"commonjs\") {
  console.log(\"   package.json type: commonjs ✅\");
} else {
  console.error(\"   package.json type:\", pkg.type, \"❌ (should be commonjs)\");
  process.exit(1);
}
console.log(\"   main:\", pkg.main);
console.log(\"   types:\", pkg.types);
" || exit 1

echo ""
echo "🎉 All package loading tests passed!"
'
