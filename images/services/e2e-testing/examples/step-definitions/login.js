const { Given, When, Then } = require('@cucumber/cucumber');
const { chromium } = require('playwright');

let browser, page;

// Setup browser before scenarios
Given('I am on the login page', async function () {
  browser = await chromium.launch({
    headless: process.env.HEADLESS !== 'false',
    executablePath: '/usr/bin/chromium-browser'
  });
  const context = await browser.newContext();
  page = await context.newPage();

  const baseUrl = process.env.BASE_URL || 'http://localhost:3000';
  await page.goto(`${baseUrl}/login`);
});

// Input actions
When('I enter valid email {string}', async function (email) {
  await page.fill('[data-testid="email-input"], #email, input[type="email"]', email);
});

When('I enter valid password {string}', async function (password) {
  await page.fill('[data-testid="password-input"], #password, input[type="password"]', password);
});

When('I enter invalid email {string}', async function (email) {
  await page.fill('[data-testid="email-input"], #email, input[type="email"]', email);
});

When('I enter invalid password {string}', async function (password) {
  await page.fill('[data-testid="password-input"], #password, input[type="password"]', password);
});

When('I click the login button', async function () {
  await page.click('[data-testid="login-button"], button[type="submit"], .login-btn');
});

When('I click the login button without entering credentials', async function () {
  await page.click('[data-testid="login-button"], button[type="submit"], .login-btn');
});

// Assertions
Then('I should be redirected to the dashboard', async function () {
  await page.waitForURL(/.*\/dashboard.*/);
});

Then('I should see a welcome message', async function () {
  const welcomeMessage = await page.locator('[data-testid="welcome-message"], .welcome, .alert-success');
  await welcomeMessage.waitFor();
});

Then('I should see an error message {string}', async function (expectedMessage) {
  const errorElement = await page.locator('[data-testid="error-message"], .error, .alert-danger');
  await errorElement.waitFor();
  const actualMessage = await errorElement.textContent();
  if (!actualMessage.includes(expectedMessage)) {
    throw new Error(`Expected error message "${expectedMessage}" but got "${actualMessage}"`);
  }
});

Then('I should remain on the login page', async function () {
  const url = page.url();
  if (!url.includes('/login')) {
    throw new Error(`Expected to remain on login page but current URL is ${url}`);
  }
});

Then('I should see validation errors', async function () {
  const errorElements = await page.locator('.validation-error, .field-error, .is-invalid').count();
  if (errorElements === 0) {
    throw new Error('No validation errors found');
  }
});

Then('the email field should show {string}', async function (expectedMessage) {
  const emailError = await page.locator('[data-testid="email-error"], #email + .error, .email-validation');
  await emailError.waitFor();
  const actualMessage = await emailError.textContent();
  if (!actualMessage.includes(expectedMessage)) {
    throw new Error(`Expected email error "${expectedMessage}" but got "${actualMessage}"`);
  }
});

Then('the password field should show {string}', async function (expectedMessage) {
  const passwordError = await page.locator('[data-testid="password-error"], #password + .error, .password-validation');
  await passwordError.waitFor();
  const actualMessage = await passwordError.textContent();
  if (!actualMessage.includes(expectedMessage)) {
    throw new Error(`Expected password error "${expectedMessage}" but got "${actualMessage}"`);
  }
});

// Cleanup after scenarios
const { After } = require('@cucumber/cucumber');
After(async function () {
  if (browser) {
    await browser.close();
  }
});