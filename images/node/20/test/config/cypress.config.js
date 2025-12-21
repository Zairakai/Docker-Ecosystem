// Cypress configuration for end-to-end testing
const { defineConfig } = require('cypress');

module.exports = defineConfig({
  // Environment
  env: {
    NODE_ENV: 'test',
    CI: true
  },

  // E2E Testing configuration
  e2e: {
    // Base URL for the application
    baseUrl: 'http://localhost:3000',

    // Spec patterns
    specPattern: [
      'cypress/e2e/**/*.cy.{js,jsx,ts,tsx}',
      'cypress/integration/**/*.spec.{js,jsx,ts,tsx}'
    ],

    // Support file
    supportFile: 'cypress/support/e2e.js',

    // Fixtures folder
    fixturesFolder: 'cypress/fixtures',

    // Screenshots and videos
    screenshotsFolder: 'cypress/screenshots',
    videosFolder: 'cypress/videos',

    // Downloads folder
    downloadsFolder: 'cypress/downloads',

    // Setup node events
    setupNodeEvents(on, config) {
      // Code coverage plugin
      require('@cypress/code-coverage/task')(on, config);

      // File preprocessing
      on('file:preprocessor', require('@cypress/webpack-preprocessor')());

      // Task definitions
      on('task', {
        log(message) {
          console.log(message);
          return null;
        },
        table(message) {
          console.table(message);
          return null;
        }
      });

      return config;
    },

    // Test isolation
    testIsolation: true,

    // Experimental features
    experimentalStudio: true,
    experimentalMemoryManagement: true,

    // Browser launch options
    chromeWebSecurity: false,
    modifyObstructiveThirdPartyCode: true
  },

  // Component Testing configuration
  component: {
    // Development server
    devServer: {
      framework: 'create-react-app',
      bundler: 'webpack'
    },

    // Spec patterns
    specPattern: [
      'src/**/*.cy.{js,jsx,ts,tsx}',
      'components/**/*.cy.{js,jsx,ts,tsx}'
    ],

    // Support file
    supportFile: 'cypress/support/component.js',

    // Setup node events
    setupNodeEvents(on, config) {
      require('@cypress/code-coverage/task')(on, config);
      return config;
    }
  },

  // Global configuration
  // Timeouts
  defaultCommandTimeout: 10000,
  execTimeout: 60000,
  taskTimeout: 60000,
  pageLoadTimeout: 60000,
  requestTimeout: 10000,
  responseTimeout: 30000,

  // Viewport
  viewportWidth: 1280,
  viewportHeight: 720,

  // Screenshots and videos
  screenshotOnRunFailure: true,
  video: false,
  videoCompression: 32,
  videoUploadOnPasses: false,

  // Retries
  retries: {
    runMode: 2,
    openMode: 0
  },

  // Waiting and delays
  watchForFileChanges: false,
  animationDistanceThreshold: 5,
  waitForAnimations: true,
  scrollBehavior: 'center',

  // Browser configuration
  chromeWebSecurity: false,
  blockHosts: [
    '*.google-analytics.com',
    '*.googletagmanager.com',
    '*.hotjar.com',
    '*.facebook.net',
    '*.doubleclick.net'
  ],

  // User agent
  userAgent: 'Cypress Test Runner',

  // Experimental features
  experimentalFetchPolyfill: true,
  experimentalInteractiveRunEvents: true,
  experimentalRunAllSpecs: true,

  // Logging
  trashAssetsBeforeRuns: true,
  reporter: 'cypress-multi-reporters',
  reporterOptions: {
    reporterEnabled: 'mochawesome,mocha-junit-reporter',
    mochawesomeReporterOptions: {
      reportDir: 'cypress/reports/mochawesome',
      overwrite: false,
      html: true,
      json: true,
      timestamp: 'mmddyyyy_HHMMss'
    },
    mochaJunitReporterReporterOptions: {
      mochaFile: 'cypress/reports/junit/results-[hash].xml'
    }
  },

  // Node.js version compatibility
  nodeVersion: 'system',

  // File server options
  fileServerFolder: '',

  // Project ID (for Cypress Cloud)
  projectId: undefined,

  // Custom commands and utilities
  includeShadowDom: true,

  // Environment variables
  env: {
    // API endpoints
    apiUrl: 'http://localhost:3001/api',

    // Test data
    testUser: {
      email: 'test@example.com',
      password: 'testpassword123'
    },

    // Feature flags
    enableFeatureX: true,
    enableFeatureY: false,

    // Coverage settings
    coverage: true,
    codeCoverage: {
      exclude: [
        'cypress/**/*',
        'node_modules/**/*',
        'coverage/**/*'
      ]
    }
  },

  // Browser-specific configuration
  browsers: [
    {
      name: 'chromium',
      family: 'chromium',
      channel: 'stable',
      displayName: 'Chromium',
      version: '',
      path: '/usr/bin/chromium-browser',
      majorVersion: ''
    },
    {
      name: 'firefox',
      family: 'firefox',
      channel: 'stable',
      displayName: 'Firefox',
      version: '',
      path: '/usr/bin/firefox',
      majorVersion: ''
    }
  ],

  // Lighthouse configuration (if plugin is installed)
  lighthouse: {
    performance: 50,
    accessibility: 90,
    'best-practices': 85,
    seo: 85,
    pwa: 50
  },

  // Custom configuration
  hosts: {
    'localhost': '127.0.0.1'
  },

  // Security
  chromeWebSecurity: false,

  // Memory management
  numTestsKeptInMemory: 0,

  // Debugging
  slowTestThreshold: 10000,

  // Parallel execution
  record: false,
  parallel: false,

  // Tags for test organization
  tags: ['e2e', 'integration', 'smoke', 'regression']
});