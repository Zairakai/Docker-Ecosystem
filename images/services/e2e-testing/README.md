# E2E Testing - Playwright + Gherkin/Cucumber

<!-- Image Stats -->
[![Docker Pulls][pulls-badge]][dockerhub]
[![Image Size][size-badge]][dockerhub]

<!-- CI/CD & Quality -->
[![Pipeline][pipeline-badge]][pipeline]
[![License][license-badge]][license]

<!-- Community -->
[![Discord][discord-badge]][discord]
Complete end-to-end testing environment with Playwright and BDD (Behavior-Driven Development) support.

Part of the [Zairakai Docker Ecosystem][ecosystem].

---

## Quick Start

```bash
docker pull zairakai/e2e-testing:latest

docker run --rm \
  -v ./tests:/tests \
  -v ./features:/features \
  --network host \
  zairakai/e2e-testing:latest \
  npx playwright test
```

---

## Included Tools

- **Playwright** - Cross-browser E2E testing (Chromium, Firefox, WebKit)
- **Cucumber** - Gherkin/BDD test runner
- **Allure** - Test reporting
- **Axe** - Accessibility testing

---

## Docker Compose

```yaml
services:
  e2e-tests:
    image: zairakai/e2e-testing:latest
    volumes:
      - ./tests:/app/tests
      - ./features:/app/features
      - ./playwright.config.js:/app/playwright.config.js
    environment:
      BASE_URL: http://nginx
    depends_on:
      - nginx
    command: npx playwright test
```

---

## Playwright Configuration

```javascript
// playwright.config.js
module.exports = {
  testDir: './tests',
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
    { name: 'firefox', use: { browserName: 'firefox' } },
    { name: 'webkit', use: { browserName: 'webkit' } },
  ],
};
```

---

## Gherkin/BDD Example

```gherkin
# features/login.feature
Feature: User Login
  As a registered user
  I want to log in to the application
  So that I can access my dashboard

  Scenario: Successful login
    Given I am on the login page
    When I enter valid credentials
    And I click the login button
    Then I should see the dashboard
```

```javascript
// step_definitions/login.steps.js
Given('I am on the login page', async ({ page }) => {
  await page.goto('/login');
});

When('I enter valid credentials', async ({ page }) => {
  await page.fill('[name="email"]', 'user@example.com');
  await page.fill('[name="password"]', 'password');
});

When('I click the login button', async ({ page }) => {
  await page.click('button[type="submit"]');
});

Then('I should see the dashboard', async ({ page }) => {
  await expect(page).toHaveURL('/dashboard');
});
```

---

## Use Cases

- **E2E Testing**: Full user journey testing
- **Cross-Browser**: Test on Chromium, Firefox, WebKit
- **BDD**: Business-readable test scenarios
- **Accessibility**: A11y compliance testing
- **Visual Regression**: Screenshot comparison

---

## CI/CD Integration

```yaml
# .gitlab-ci.yml
test:e2e:
  stage: test
  image: zairakai/e2e-testing:latest
  script:
    - npx playwright test
  artifacts:
    when: on_failure
    paths:
      - playwright-report/
      - test-results/
```

---

## Running Tests

```bash
# All tests
docker run --rm -v ./tests:/app/tests zairakai/e2e-testing npx playwright test

# Specific test
docker run --rm -v ./tests:/app/tests zairakai/e2e-testing npx playwright test login.spec.js

# Debug mode
docker run --rm -it -v ./tests:/app/tests zairakai/e2e-testing npx playwright test --debug

# Generate report
docker run --rm -v ./tests:/app/tests zairakai/e2e-testing npx playwright show-report
```

---

**Documentation**: [Zairakai Docker Ecosystem][ecosystem]

## Support

[![Issues][issues-badge]][issues]
[![Discord][discord-badge]][discord]

[issues]: https://gitlab.com/zairakai/docker-ecosystem/-/issues

<!-- Badge References -->
[pulls-badge]: https://img.shields.io/docker/pulls/zairakai/e2e-testing?logo=docker&logoColor=white
[size-badge]: https://img.shields.io/docker/image-size/zairakai/e2e-testing/latest?logo=docker&logoColor=white&label=size
[pipeline-badge]: https://gitlab.com/zairakai/docker-ecosystem/badges/main/pipeline.svg
[pipeline]: https://gitlab.com/zairakai/docker-ecosystem/-/pipelines
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license]: https://gitlab.com/zairakai/docker-ecosystem/-/blob/main/LICENSE
[discord-badge]: https://img.shields.io/discord/1260000352699289621?logo=discord&label=Discord&color=5865F2
[discord]: https://discord.gg/MAmD5SG8Zu
[issues-badge]: https://img.shields.io/gitlab/issues/open-raw/zairakai%2Fdocker-ecosystem?logo=gitlab&label=Issues
[ecosystem]: https://gitlab.com/zairakai/docker-ecosystem
[dockerhub]: https://hub.docker.com/r/zairakai/e2e-testing
