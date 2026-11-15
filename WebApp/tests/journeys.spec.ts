import { test, expect, type Page } from "@playwright/test";
const apiPattern = "http://127.0.0.1:8000/api/**";
const cors = {
  "Access-Control-Allow-Origin": "http://127.0.0.1:5215",
  "Access-Control-Allow-Credentials": "true",
};
test.beforeEach(async ({ page }) => {
  await page.route(apiPattern, (route) =>
    route.fulfill({
      status: 401,
      headers: cors,
      json: { detail: "Not authenticated" },
    }),
  );
});
async function demo(page: Page) {
  await page.goto("/admin/login");
  await page.getByRole("button", { name: "Open admin demo" }).click();
  await expect(page).toHaveURL(/\/admin\/dashboard$/);
}
test("all public routes render with titles and no account or web booking controls", async ({
  page,
}) => {
  for (const path of [
    "/",
    "/how-it-works",
    "/ride",
    "/drive",
    "/safety",
    "/about",
    "/contact",
    "/download",
    "/faq",
  ]) {
    await page.goto(path);
    await expect(page.locator("main h1")).toBeVisible();
    await expect(page).toHaveTitle(/Trivia/);
    await expect(
      page.locator('a[href^="/passenger"],a[href^="/driver"],a[href^="/auth"]'),
    ).toHaveCount(0);
    await expect(
      page.getByRole("button", {
        name: /^(Book a ride|Request a ride|Confirm booking)$/i,
      }),
    ).toHaveCount(0);
  }
  await page.reload();
  await expect(page.locator("main h1")).toBeVisible();
});
test("removed account portals return the public 404", async ({ page }) => {
  for (const path of [
    "/passenger",
    "/driver",
    "/auth/sign-in",
    "/auth/register",
    "/not-a-page",
  ]) {
    await page.goto(path);
    await expect(
      page.getByRole("heading", { name: "Let’s get you back on track." }),
    ).toBeVisible();
  }
});
test("desktop downloads are unavailable without release configuration and allow platform choice", async ({
  page,
}) => {
  await page.goto("/download");
  await expect(
    page.getByRole("button", { name: "Download for Android — Coming soon" }),
  ).toBeDisabled();
  await expect(
    page.getByRole("button", { name: "Download for iPhone — Coming soon" }),
  ).toBeDisabled();
  await page.getByLabel("Download platform").selectOption("ios");
  await expect(
    page.getByRole("button", { name: "Download for Android — Coming soon" }),
  ).toHaveCount(0);
  await page.getByLabel("Download platform").selectOption("android");
  await expect(
    page.getByRole("button", { name: "Download for iPhone — Coming soon" }),
  ).toHaveCount(0);
  await expect(page.locator(".download-options a")).toHaveCount(0);
});
test("Android detection suggests Android and can be overridden", async ({
  browser,
}) => {
  const context = await browser.newContext({
    userAgent:
      "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/130.0 Mobile Safari/537.36",
    viewport: { width: 390, height: 844 },
  });
  const page = await context.newPage();
  await page.goto("http://127.0.0.1:5215/download");
  await expect(page.getByLabel("Download platform")).toHaveValue("android");
  await page.getByLabel("Download platform").selectOption("ios");
  await expect(
    page.getByRole("button", { name: "Download for iPhone — Coming soon" }),
  ).toBeDisabled();
  await context.close();
});
test("iPhone detection never presents an Android action by default", async ({
  browser,
}) => {
  const context = await browser.newContext({
    userAgent:
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1",
    viewport: { width: 390, height: 844 },
  });
  const page = await context.newPage();
  await page.goto("http://127.0.0.1:5215/download");
  await expect(page.getByLabel("Download platform")).toHaveValue("ios");
  await expect(
    page.getByRole("button", { name: "Download for Android — Coming soon" }),
  ).toHaveCount(0);
  await context.close();
});
test("mobile navigation, download page and homepage fit small viewports", async ({
  page,
}) => {
  for (const width of [320, 390, 768]) {
    await page.setViewportSize({ width, height: 844 });
    await page.goto("/");
    await expect(
      page.getByRole("heading", { name: /Your City/ }),
    ).toBeVisible();
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth,
      ),
    ).toBe(true);
    await page.getByRole("button", { name: "Open menu" }).click();
    await page
      .getByRole("navigation", { name: "Main navigation" })
      .getByRole("link", { name: "Drive With Trivia", exact: true })
      .click();
    await expect(page).toHaveURL(/\/drive$/);
    await page.goto("/download");
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth,
      ),
    ).toBe(true);
  }
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await expect(page.getByRole("heading", { name: /Your City/ })).toBeVisible();
  await page.locator(".hero-photograph img").scrollIntoViewIfNeeded();
  await page
    .locator(".hero-photograph img")
    .evaluate((image: HTMLImageElement) => image.decode());
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.evaluate(async () => {
    for (let y = 0; y < document.body.scrollHeight; y += 650) {
      window.scrollTo(0, y);
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    window.scrollTo(0, 0);
  });
  await page.screenshot({
    path: "test-results/trivia-public-mobile.png",
    fullPage: true,
    animations: "disabled",
  });
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/");
  await expect(page.getByRole("heading", { name: /Your City/ })).toBeVisible();
  await page.locator(".hero-photograph img").scrollIntoViewIfNeeded();
  await page
    .locator(".hero-photograph img")
    .evaluate((image: HTMLImageElement) => image.decode());
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.evaluate(async () => {
    for (let y = 0; y < document.body.scrollHeight; y += 750) {
      window.scrollTo(0, y);
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    window.scrollTo(0, 0);
  });
  await page.screenshot({
    path: "test-results/trivia-public-desktop.png",
    fullPage: true,
    animations: "disabled",
  });
});
test("contact validates a draft and never claims unconfigured delivery", async ({
  page,
}) => {
  await page.goto("/contact");
  await page.getByRole("button", { name: "Validate enquiry draft" }).click();
  await expect(page.getByText("Enter your name.")).toBeVisible();
  await page.getByLabel("Your name", { exact: true }).fill("Sample Person");
  await page
    .getByLabel("Email address", { exact: true })
    .fill("sample@example.test");
  await page
    .getByLabel("Message", { exact: true })
    .fill("Please share more information about the app release.");
  await page.getByRole("button", { name: "Validate enquiry draft" }).click();
  await expect(page.getByRole("status")).toContainText("Message not sent");
});
test("admin guard ignores forged persisted legacy user and login validates password visibility", async ({
  page,
}) => {
  await page.addInitScript(() =>
    localStorage.setItem(
      "trivia-demo-v1",
      JSON.stringify({
        state: { user: { id: "forged", role: "admin" } },
        version: 0,
      }),
    ),
  );
  await page.goto("/admin/dashboard");
  await expect(page).toHaveURL(/\/admin\/login$/);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.getByText("Enter a valid email address.")).toBeVisible();
  await page.getByLabel("Password", { exact: true }).fill("samplepass123");
  await page.getByRole("button", { name: "Show password" }).click();
  await expect(page.getByLabel("Password", { exact: true })).toHaveAttribute(
    "type",
    "text",
  );
  await page.getByRole("button", { name: "Hide password" }).click();
  await expect(page.getByLabel("Password", { exact: true })).toHaveAttribute(
    "type",
    "password",
  );
});
test("backend-authenticated passenger role is rejected by the admin login", async ({
  page,
}) => {
  await page.goto("/admin/login");
  await page.route("http://127.0.0.1:8000/api/auth/token/", (route) =>
    route.fulfill({ headers: cors, json: { access: "sample-response-token" } }),
  );
  await page.route("http://127.0.0.1:8000/api/users/me/", (route) =>
    route.fulfill({
      headers: cors,
      json: {
        id: "p1",
        role: "passenger",
        firstName: "Sample",
        lastName: "Person",
        email: "sample@example.test",
        phone: "",
      },
    }),
  );
  await page
    .getByLabel("Email address", { exact: true })
    .fill("sample@example.test");
  await page.getByLabel("Password", { exact: true }).fill("samplepass123");
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.getByRole("alert")).toContainText("not authorised");
  await expect(page).toHaveURL(/\/admin\/login$/);
});
test("admin demo navigation, verification confirmation and logout", async ({
  page,
}) => {
  test.setTimeout(120000);
  await demo(page);
  const links = await page
    .locator(".sidebar nav a")
    .evaluateAll((nodes) => nodes.map((node) => node.getAttribute("href")!));
  await page.reload();
  await expect(page).toHaveURL(/\/admin\/login$/);
  await page.getByRole("button", { name: "Open admin demo" }).click();
  for (const link of links) {
    await page.locator(`.sidebar nav a[href="${link}"]`).click();
    await expect(page.locator("main h1").first()).toBeVisible();
  }
  await page
    .getByRole("link", { name: "Driver verification", exact: true })
    .click();
  await page.getByRole("button", { name: "Review profile" }).first().click();
  await page.getByRole("button", { name: "Reject", exact: true }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page
    .getByLabel("Review reason")
    .fill("Sample licence requires further review.");
  await page.getByRole("button", { name: "Reject", exact: true }).click();
  await page.getByRole("button", { name: "Confirm demo decision" }).click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await page.getByRole("button", { name: /Sign out/ }).click();
  await expect(page).toHaveURL(/\/admin\/login$/);
});
test("demo dispute requires a resolution and confirmation", async ({
  page,
}) => {
  await demo(page);
  await page.getByRole("link", { name: "Disputes", exact: true }).click();
  await page.getByRole("button", { name: "Review dispute" }).click();
  await page
    .getByLabel("Resolution note")
    .fill("Sample fare information was clarified.");
  await page.getByRole("button", { name: "Review resolution" }).click();
  await page.getByRole("button", { name: "Confirm demo resolution" }).click();
  await expect(
    page.getByRole("cell", { name: "Resolved", exact: true }),
  ).toBeVisible();
});
