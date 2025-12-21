import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './features',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { outputFolder: 'reports/playwright-report' }],
    ['json', { outputFile: 'reports/playwright-report.json' }],
    ['junit', { outputFile: 'reports/playwright-report.xml' }]
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: {
        …devices['Desktop Chrome'],
        executablePath: '/usr/bin/chromium-browser'
      },
    },
    {
      name: 'firefox',
      use: {
        …devices['Desktop Firefox'],
        executablePath: '/usr/bin/firefox'
      },
    },
    {
      name: 'webkit',
      use: {
        …devices['Desktop Safari']
      },
    },
  ],
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
