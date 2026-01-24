#!/usr/bin/env node
/**
 * Transform package.json for CommonJS distribution
 *
 * Usage: node transform-package-json.js <input> <output>
 */
const fs = require('fs');
const path = require('path');

const pkgPath = process.argv[2];
const outputPath = process.argv[3];

if (!pkgPath || !outputPath) {
  console.error('Usage: transform-package-json.js <input> <output>');
  process.exit(1);
}

const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));

// Determine exports based on package structure
const exports = {
  '.': {
    types: './index.d.ts',
    require: './index.js',
    default: './index.js'
  }
};

// Add client export if it exists (for menu-registry)
if (pkg.name === '@wolfgangm81/menu-registry') {
  exports['./client'] = {
    types: './client.d.ts',
    require: './client.js',
    default: './client.js'
  };
}

// Transform for CommonJS distribution
const distPkg = {
  name: pkg.name,
  version: pkg.version,
  description: pkg.description,
  type: 'commonjs',  // We compile to CommonJS
  main: './index.js',
  types: './index.d.ts',
  exports,
  repository: pkg.repository,
  publishConfig: pkg.publishConfig,
  license: pkg.license || 'MIT',
  author: pkg.author
};

fs.writeFileSync(outputPath, JSON.stringify(distPkg, null, 2));
