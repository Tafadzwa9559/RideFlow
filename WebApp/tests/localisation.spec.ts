import { test, expect } from "@playwright/test";
import {
  projectConfig,
  publicMetadata,
  serviceAvailability,
  supportedLanguages,
} from "../src/config/project";
import { money } from "../src/utils/format";
import {
  normalisePhone,
  formatDate,
  formatDateTime,
} from "../src/utils/localisation";

test("Zimbabwe defaults do not activate unverified services or translations", () => {
  expect(projectConfig.developer).toBe("MOrdec Solutions (Private) Limited");
  expect(serviceAvailability.coverageCities).toEqual([]);
  expect(serviceAvailability.enabledPaymentMethods).toEqual([]);
  expect(supportedLanguages).toEqual(["en"]);
  expect(money(1234.5)).toBe("US$1,234.50");
  expect(money(8.5, "EUR")).toContain("€8.50");
});

test("phone normalisation handles Zimbabwe and international input without accepting malformed values", () => {
  for (const value of [
    "077 123 4567",
    "+263 (77) 123-4567",
    "00263771234567",
    "263771234567",
  ]) {
    expect(normalisePhone(value)).toBe("+263771234567");
  }
  expect(normalisePhone("0242 712 3456")).toBe("+2632427123456");
  expect(normalisePhone("+44 20 7123 4567")).toBe("+442071234567");
  for (const value of [
    "",
    "07712",
    "+2630771234567",
    "+263791234567",
    "+26377123456789",
    "+0000000000",
    "abc0771234567",
    "+1234567890123456",
  ]) {
    expect(normalisePhone(value)).toBeNull();
  }
});

test("dates respect Harare midnight and reject ambiguous backend timestamps", () => {
  expect(formatDate("2026-11-12T23:30:00Z").replace(/[ ,]/g, "")).toBe(
    "13Nov2026",
  );
  expect(formatDateTime("2026-11-12T23:30:00Z")).toContain("01:30");
  expect(formatDate("2026-11-13T01:30:00+02:00").replace(/[ ,]/g, "")).toBe(
    "13Nov2026",
  );
  expect(formatDate("2026-11-12T10:00:00")).toBe("Date unavailable");
  expect(formatDate("invalid")).toBe("Date unavailable");
});

test("production HTML contains official metadata before JavaScript runs", async ({
  request,
}) => {
  const response = await request.get("http://127.0.0.1:4225/");
  expect(response.ok()).toBe(true);
  const html = await response.text();
  expect(html).toContain("<title>Trivia | Ride-Hailing in Zimbabwe</title>");
  expect(html).toContain(projectConfig.metaDescription);
  expect(html).toContain('name="application-name" content="Trivia"');
  expect(html).toContain(
    'name="author" content="MOrdec Solutions (Private) Limited"',
  );
  const script = html.match(
    /<script[^>]*id="trivia-product-metadata"[^>]*>([\s\S]*?)<\/script>/,
  )?.[1];
  expect(script).toBeTruthy();
  const data = JSON.parse(script!);
  expect(data.creator.name).toBe(projectConfig.developer);
  expect(data.description).toContain("in development");
  for (const key of [
    "offers",
    "aggregateRating",
    "review",
    "downloadUrl",
    "address",
  ])
    expect(data[key]).toBeUndefined();
});

test("all public routes retain official attribution, metadata and unavailable downloads", async ({
  page,
}) => {
  test.setTimeout(120000);
  await page.emulateMedia({ reducedMotion: "reduce" });
  for (const width of [320, 1440]) {
    await page.setViewportSize({ width, height: 1000 });
    for (const [path, [title, description]] of Object.entries(publicMetadata)) {
      await page.goto(path);
      await expect(page.locator("main h1")).toBeVisible();
      await page.evaluate(() => document.fonts.ready);
      await expect(page).toHaveTitle(title);
      await expect(page.locator('meta[name="description"]')).toHaveAttribute(
        "content",
        description,
      );
      await expect(page.locator('meta[property="og:title"]')).toHaveAttribute(
        "content",
        title,
      );
      await expect(page.locator('meta[name="twitter:title"]')).toHaveAttribute(
        "content",
        title,
      );
      await expect(page.locator(".site-footer")).toContainText(
        "Developed by MOrdec Solutions (Private) Limited.",
      );
      await expect(page.locator("body")).not.toContainText(
        /RideFlow|Mordec Solutions|MOrdec Technologies|Cape Town/,
      );
      expect(
        await page.evaluate(
          () => document.documentElement.scrollWidth <= innerWidth,
        ),
      ).toBe(true);
      await expect(
        page.locator(
          'a[href^="/passenger"],a[href^="/driver"],a[href^="/auth"]',
        ),
      ).toHaveCount(0);
      if (path === "/about") {
        await expect(page.locator("main")).toContainText(
          projectConfig.developer,
        );
        await expect(
          page.locator('img[src*="harare-"]').first(),
        ).toHaveAttribute("alt", /Harare, Zimbabwe/);
        await page.screenshot({
          path: `test-results/branding-about-${width}.png`,
          fullPage: true,
          animations: "disabled",
        });
      }
      if (path === "/download") {
        await expect(
          page.getByRole("button", {
            name: /Download for Android.*Coming soon/,
          }),
        ).toBeDisabled();
        await expect(
          page.getByRole("button", {
            name: /Download for iPhone.*Coming soon/,
          }),
        ).toBeDisabled();
      }
    }
  }
});

test("admin settings validate and normalise phone input and show localisation defaults", async ({
  page,
}) => {
  await page.route("http://127.0.0.1:8000/api/**", (route) =>
    route.fulfill({
      status: 401,
      headers: {
        "Access-Control-Allow-Origin": "http://127.0.0.1:5215",
        "Access-Control-Allow-Credentials": "true",
      },
      json: { detail: "Not authenticated" },
    }),
  );
  await page.goto("/admin/login");
  await page.getByRole("button", { name: "Open admin demo" }).click();
  await page.locator('.sidebar a[href="/admin/settings"]').click();
  await expect(page.locator("main")).toContainText("Africa/Harare");
  await page.getByLabel("Phone", { exact: true }).fill("07712");
  await page.getByRole("button", { name: "Save demo profile" }).click();
  await expect(
    page.getByText("Enter a valid Zimbabwe or international phone number."),
  ).toBeVisible();
  await page.getByLabel("Phone", { exact: true }).fill("077 123 4567");
  await page.getByRole("button", { name: "Save demo profile" }).click();
  await expect(
    page.getByText("Demo profile saved in this browser"),
  ).toBeVisible();
  const phone = await page.evaluate(
    () => JSON.parse(localStorage.getItem("trivia-demo-v1")!).state.user.phone,
  );
  expect(phone).toBe("+263771234567");
  await expect(page.locator(".app-footer")).toContainText(
    "Developed by MOrdec Solutions (Private) Limited",
  );
});
