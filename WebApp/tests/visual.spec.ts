import { test, expect } from "@playwright/test";
test("all public pages render licensed photography and a neutral palette on desktop and mobile", async ({
  page,
}) => {
  test.setTimeout(180000);
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  for (const width of [1440, 390]) {
    await page.setViewportSize({ width, height: 1000 });
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
      const images = page.locator('main img[src^="/photos/"]');
      expect(await images.count()).toBeGreaterThan(0);
      for (const image of await images.all()) {
        await image.scrollIntoViewIfNeeded();
        await image.evaluate((node: HTMLImageElement) => node.decode());
        expect(
          await image.evaluate(
            (node: HTMLImageElement) => node.naturalWidth > 0 && node.complete,
          ),
        ).toBe(true);
        await expect(image).toHaveAttribute("alt", /.+/);
      }
      expect(
        await page.evaluate(
          () => document.documentElement.scrollWidth <= innerWidth,
        ),
      ).toBe(true);
      const navy = await page.locator(".marketing *").evaluateAll(
        (nodes) =>
          nodes.filter((n) => {
            const style = getComputedStyle(n);
            return ["rgb(2, 6, 23)", "rgb(15, 23, 42)", "rgb(30, 41, 59)"].some(
              (c) => style.backgroundColor === c || style.color === c,
            );
          }).length,
      );
      expect(navy).toBe(0);
      await page.evaluate(async () => {
        for (let y = 0; y < document.body.scrollHeight; y += innerHeight / 2) {
          scrollTo(0, y);
          await new Promise((resolve) => setTimeout(resolve, 90));
        }
        scrollTo(0, 0);
      });
      await expect
        .poll(() =>
          page
            .locator("[data-reveal]")
            .evaluateAll((nodes) =>
              nodes
                .filter((node) => getComputedStyle(node).opacity !== "1")
                .map(
                  (node) =>
                    `${location.pathname}: ${node.tagName}.${node.className} (${getComputedStyle(node).opacity})`,
                ),
            ),
        )
        .toEqual([]);
      await page.screenshot({
        path: `test-results/redesign-${path === "/" ? "home" : path.slice(1)}-${width}.png`,
        fullPage: true,
        animations: "disabled",
      });
    }
  }
  expect(errors).toEqual([]);
});
test("admin sample workspace uses white neutral surfaces and keeps authentication guards", async ({
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
  await page.goto("/admin/dashboard");
  await expect(page).toHaveURL(/\/admin\/login$/);
  await page.getByRole("button", { name: "Open admin demo" }).click();
  await expect(page.locator("main h1")).toBeVisible();
  expect(
    await page
      .locator(".sidebar")
      .evaluate((n) => getComputedStyle(n).backgroundColor),
  ).toBe("rgb(255, 255, 255)");
  expect(
    await page.locator(".sidebar").evaluate((n) => getComputedStyle(n).color),
  ).toBe("rgb(102, 102, 102)");
  await page.screenshot({
    path: "test-results/redesign-admin.png",
    fullPage: true,
    animations: "disabled",
  });
});
