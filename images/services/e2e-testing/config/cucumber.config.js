module.exports = {
  default: {
    require: ['step-definitions/**/*.js'],
    format: [
      'progress-bar',
      'html:reports/cucumber-report.html',
      'json:reports/cucumber-report.json',
      'junit:reports/cucumber-report.xml'
    ],
    paths: ['features/**/*.feature'],
    parallel: 2,
    retry: 1,
    timeout: 30000,
    worldParameters: {
      browser: process.env.BROWSER || 'chromium',
      headless: process.env.HEADLESS !== 'false',
      screenshot: process.env.SCREENSHOT || 'on-failure',
      video: process.env.VIDEO || 'retain-on-failure'
    }
  }
};