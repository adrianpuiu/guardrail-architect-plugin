// Guardrail Architect — Dependency Rules (dependency-cruiser)
// Run: npx depcruise src --config .dependency-cruiser.cjs --output-type err
// These are EXECUTABLE architecture tests — violations break CI.
module.exports = {
  forbidden: [
    {
      name: 'no-circular',
      severity: 'error',
      comment: 'Circular dependencies make code unpredictable for agents and humans alike',
      from: {},
      to: { circular: true }
    },
    {
      name: 'domain-independence',
      severity: 'error',
      comment: 'Domain/core layer must not depend on infrastructure, API, or database code',
      from: { path: '^src/(domain|core|models)' },
      to: { path: '^src/(infrastructure|api|controllers|database|db)' }
    },
    {
      name: 'no-ui-to-db',
      severity: 'error',
      comment: 'UI components must never import database or storage modules directly',
      from: { path: '^src/(components|pages|views)' },
      to: { path: '^src/(database|db|repositories|storage)' }
    },
    {
      name: 'enforce-service-layer',
      severity: 'warn',
      comment: 'Controllers/routes should go through services, not directly to repositories',
      from: { path: '^src/(controllers|routes|api)' },
      to: { path: '^src/(repositories|database|db)' }
    },
    {
      name: 'no-reaching-into-modules',
      severity: 'warn',
      comment: 'Import from module index, not from internal files',
      from: { path: '^src/' },
      to: { path: '^src/[^/]+/(?!index)' },
    }
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: 'tsconfig.json' },
    enhancedResolveOptions: {
      exportsFields: ['exports'],
      conditionNames: ['import', 'require', 'node', 'default'],
    },
    reporterOptions: {
      dot: { collapsePattern: 'node_modules/[^/]+' },
    },
  }
};
