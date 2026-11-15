import { expect, test } from "@playwright/test";

const routes = [
  "/",
  "/how-it-works",
  "/ride",
  "/drive",
  "/safety",
  "/about",
  "/contact",
  "/download",
  "/faq",
];
test("local fonts, heading hierarchy and responsive type work across all public routes", async ({
  page,
}) => {
  test.setTimeout(120000);
  await page.emulateMedia({ reducedMotion: "reduce" });
  const failedFonts: string[] = [];
  page.on("requestfailed", (request) => {
    if (request.url().includes("/fonts/")) failedFonts.push(request.url());
  });
  for (const width of [320, 1440]) {
    await page.setViewportSize({ width, height: 1000 });
    for (const route of routes) {
      await page.goto(route);
      await expect(page.locator("main h1")).toHaveCount(1);
      await page.evaluate(() => document.fonts.ready);
      const result = await page.evaluate(() => {
        const heading = document.querySelector("main h1")!;
        const style = getComputedStyle(heading);
        const paragraph = document.querySelector("main p")!;
        return {
          font: style.fontFamily,
          size: parseFloat(style.fontSize),
          weight: style.fontWeight,
          bodyFont: getComputedStyle(paragraph).fontFamily,
          overflow: document.documentElement.scrollWidth > innerWidth,
          headingOverflow: Array.from(
            document.querySelectorAll("main h1,main h2,main h3"),
          ).some((node) => node.scrollWidth > node.clientWidth + 1),
          loaded: Array.from(document.fonts)
            .filter((font) => font.status === "loaded")
            .map((font) => font.family),
        };
      });
      expect(result.font).toContain("Plus Jakarta Sans");
      expect(result.bodyFont).toContain("Inter");
      expect(result.loaded).toEqual(
        expect.arrayContaining(["Inter", "Plus Jakarta Sans"]),
      );
      expect(result.weight).toBe(route === "/" ? "800" : "700");
      expect(result.size).toBeCloseTo(
        route === "/" ? (width === 320 ? 40 : 72) : width === 320 ? 36 : 56,
        0,
      );
      expect(result.overflow, `${route} overflows at ${width}px`).toBe(false);
      expect(
        result.headingOverflow,
        `${route} heading overflows at ${width}px`,
      ).toBe(false);
      if (route === "/about") {
        await expect(page.locator(".photo-context")).toHaveCSS(
          "font-size",
          "12px",
        );
      }
      await page.screenshot({
        path: `test-results/type-${route === "/" ? "home" : route.slice(1)}-${width}.png`,
        animations: "disabled",
      });
    }
  }
  expect(failedFonts).toEqual([]);
});

test("public body and control typography meet the shared scale", async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto("/");
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator(".hero-editorial > p")).toHaveCSS(
    "font-size",
    "20px",
  );
  await expect(page.locator(".hero-editorial > p")).toHaveCSS(
    "color",
    "rgb(82, 82, 82)",
  );
  await expect(
    page.locator(".site-nav .desktop-navigation > a").first(),
  ).toHaveCSS("font-size", "14px");
  await expect(
    page.locator(".site-nav .desktop-navigation > a").first(),
  ).toHaveCSS("font-weight", "500");
  await expect(page.locator(".nav-download")).toHaveCSS("font-size", "15px");
  await expect(page.locator(".introduction-editorial h2")).toHaveCSS(
    "font-size",
    "44px",
  );
  await page.setViewportSize({ width: 320, height: 1000 });
  await expect(page.locator(".hero-editorial > p")).toHaveCSS(
    "font-size",
    "18px",
  );
  await expect(page.locator(".introduction-editorial h2")).toHaveCSS(
    "font-size",
    "30px",
  );
  await page.getByRole("button", { name: "Open menu" }).click();
  await expect(
    page.getByRole("dialog").getByRole("link", { name: "Home", exact: false }),
  ).toHaveCSS("font-size", "16px");
});

test("admin keeps its compact Inter scale on desktop and mobile", async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
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
  for (const width of [1440, 320]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.evaluate(() => document.fonts.ready);
    await expect(page.locator("main h1")).toHaveCSS("font-family", /Inter/);
    const titleSize = await page
      .locator("main h1")
      .evaluate((node) => parseFloat(getComputedStyle(node).fontSize));
    expect(titleSize).toBeCloseTo(width === 320 ? 26 : 30, 0);
    await expect(page.locator("main td").first()).toHaveCSS(
      "font-size",
      "14px",
    );
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    ).toBe(true);
    await page.screenshot({
      path: `test-results/type-admin-${width}.png`,
      fullPage: true,
      animations: "disabled",
    });
  }
});
