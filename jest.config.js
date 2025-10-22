module.exports = {
  preset: 'react-native',
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json', 'node'],

  // Setup files
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],

  // Transform files
  transform: {
    '^.+\\.(js|jsx|ts|tsx)$': 'babel-jest',
  },

  // Module name mapper for path aliases
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '^@components/(.*)$': '<rootDir>/src/components/$1',
    '^@features/(.*)$': '<rootDir>/src/features/$1',
    '^@core/(.*)$': '<rootDir>/src/core/$1',
    '^@navigation/(.*)$': '<rootDir>/src/components/navigation/$1',
    '^@ui/(.*)$': '<rootDir>/src/components/ui/$1',
    '^@models/(.*)$': '<rootDir>/src/core/models/$1',
    '^@services/(.*)$': '<rootDir>/src/core/services/$1',
    '^@utils/(.*)$': '<rootDir>/src/core/utils/$1',
    '^@assets/(.*)$': '<rootDir>/assets/$1',
  },

  // Test match patterns
  testMatch: [
    '**/__tests__/**/*.(test|spec).(ts|tsx|js|jsx)',
    '**/*.(test|spec).(ts|tsx|js|jsx)',
  ],

  // Coverage configuration
  collectCoverageFrom: [
    'src/**/*.{ts,tsx,js,jsx}',
    '!src/**/*.d.ts',
    '!src/**/*.stories.{ts,tsx}',
    '!src/**/__tests__/**',
    '!src/**/__mocks__/**',
    '!src/**/index.{ts,tsx,js,jsx}',
  ],

  // Coverage thresholds - LitmonCloud Quality Gates
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },

  // Coverage reporters
  coverageReporters: ['text', 'lcov', 'html', 'json-summary'],

  // Test environment
  testEnvironment: 'node',

  // Ignore patterns
  testPathIgnorePatterns: [
    '/node_modules/',
    '/ios/',
    '/android/',
    '/dist/',
    '/build/',
  ],

  // Transform ignore patterns
  transformIgnorePatterns: [
    'node_modules/(?!(react-native|@react-native|@react-navigation|@react-native-community|react-native-vector-icons)/)',
  ],

  // Globals
  globals: {
    'ts-jest': {
      tsconfig: {
        jsx: 'react',
      },
    },
  },

  // Verbose output
  verbose: true,

  // Clear mocks between tests
  clearMocks: true,

  // Reset mocks between tests
  resetMocks: true,

  // Restore mocks between tests
  restoreMocks: true,

  // Maximum concurrent workers
  maxWorkers: '50%',

  // Cache directory
  cacheDirectory: '<rootDir>/.jest-cache',
};
