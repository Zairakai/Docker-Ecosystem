// Jest configuration for comprehensive testing
module.exports = {
  // Test environment
  testEnvironment: 'node',

  // Root directory
  rootDir: process.cwd(),

  // Test patterns
  testMatch: [
    '**/__tests__/**/*.(js|jsx|ts|tsx)',
    '**/*.(test|spec).(js|jsx|ts|tsx)'
  ],

  // Module file extensions
  moduleFileExtensions: [
    'js',
    'jsx',
    'ts',
    'tsx',
    'json',
    'node'
  ],

  // Transform configuration
  transform: {
    '^.+\\.(js|jsx)$': 'babel-jest',
    '^.+\\.(ts|tsx)$': 'ts-jest'
  },

  // Module name mapping
  moduleNameMapping: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '^~/(.*)$': '<rootDir>/$1'
  },

  // Setup files
  setupFilesAfterEnv: [
    '<rootDir>/jest.setup.js'
  ],

  // Test paths to ignore
  testPathIgnorePatterns: [
    '/node_modules/',
    '/dist/',
    '/build/',
    '/coverage/'
  ],

  // Module paths to ignore
  modulePathIgnorePatterns: [
    '/dist/',
    '/build/'
  ],

  // Coverage configuration
  collectCoverage: true,
  collectCoverageFrom: [
    'src/**/*.{js,jsx,ts,tsx}',
    'lib/**/*.{js,jsx,ts,tsx}',
    '!src/**/*.d.ts',
    '!src/**/*.stories.{js,jsx,ts,tsx}',
    '!src/**/*.test.{js,jsx,ts,tsx}',
    '!src/**/*.spec.{js,jsx,ts,tsx}',
    '!src/**/index.{js,jsx,ts,tsx}'
  ],

  // Coverage thresholds
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 70,
      statements: 70
    }
  },

  // Coverage reporters
  coverageReporters: [
    'text',
    'text-summary',
    'html',
    'lcov',
    'json',
    'clover'
  ],

  // Coverage directory
  coverageDirectory: 'coverage',

  // Verbose output
  verbose: true,

  // Fail on coverage threshold
  coveragePathIgnorePatterns: [
    '/node_modules/',
    '/dist/',
    '/build/',
    '/coverage/',
    '/test/',
    '/tests/',
    '/__tests__/',
    '/mock/',
    '/mocks/',
    '/fixture/',
    '/fixtures/'
  ],

  // Test timeout
  testTimeout: 30000,

  // Setup timeout
  setupFilesAfterEnvTimeout: 30000,

  // Clear mocks
  clearMocks: true,
  restoreMocks: true,
  resetMocks: true,

  // Error handling
  errorOnDeprecated: true,

  // Globals
  globals: {
    'ts-jest': {
      useESM: true,
      tsconfig: {
        target: 'es2020',
        module: 'esnext',
        moduleResolution: 'node',
        allowSyntheticDefaultImports: true,
        esModuleInterop: true
      }
    }
  },

  // Test environment options
  testEnvironmentOptions: {
    url: 'http://localhost:3000'
  },

  // Watch mode configuration
  watchman: false,
  watchPathIgnorePatterns: [
    '/node_modules/',
    '/dist/',
    '/build/',
    '/coverage/'
  ],

  // Snapshot configuration
  snapshotFormat: {
    escapeString: true,
    printBasicPrototype: true
  },

  // Reporter configuration
  reporters: [
    'default',
    [
      'jest-junit',
      {
        outputDirectory: 'test-results',
        outputName: 'junit.xml',
        usePathForSuiteName: true
      }
    ],
    [
      'jest-html-reporters',
      {
        publicPath: 'test-results',
        filename: 'report.html',
        expand: true
      }
    ]
  ],

  // Bail configuration
  bail: false,

  // Max workers for parallel execution
  maxWorkers: '50%',

  // Cache directory
  cacheDirectory: '/tmp/jest_cache',

  // Notify mode
  notify: false,
  notifyMode: 'failure-change',

  // Silent mode
  silent: false,

  // Detect open handles
  detectOpenHandles: true,
  forceExit: false,

  // Project configuration for multi-project setups
  projects: [
    {
      displayName: 'unit',
      testMatch: ['<rootDir>/src/**/*.(test|spec).(js|ts)'],
      testEnvironment: 'node'
    },
    {
      displayName: 'integration',
      testMatch: ['<rootDir>/tests/integration/**/*.(test|spec).(js|ts)'],
      testEnvironment: 'node'
    }
  ],

  // Mock configuration
  automock: false,
  unmockedModulePathPatterns: [
    'node_modules'
  ],

  // Dependencies to transform
  transformIgnorePatterns: [
    'node_modules/(?!(es6-module|other-es6-module)/)'
  ],

  // Preset configurations
  preset: undefined,

  // Custom matchers
  testResultsProcessor: undefined,

  // Runner configuration
  runner: 'jest-runner',

  // Test sequence
  testSequencer: '@jest/test-sequencer',

  // Extension configuration
  extensionsToTreatAsEsm: ['.ts', '.tsx'],

  // Custom resolvers
  resolver: undefined,

  // Handle process.env
  processEnv: {
    NODE_ENV: 'test'
  }
};