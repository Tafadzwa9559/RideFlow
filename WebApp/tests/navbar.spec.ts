import { test, expect } from "@playwright/test";
test("premium navbar has no overlap at each requested width", async ({
  page,
}) => {
  test.setTimeout(120000);
  for (const width of [320, 375, 390, 430, 768, 1024, 1280, 1440]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/");
    await expect(page.locator("main h1")).toBeVisible();
    await expect(page.locator(".site-nav")).toHaveCSS("opacity", "1");
    const dimensions = await page.locator(".site-nav").evaluate((n) => {
      const boxes = Array.from(n.children)
        .filter((child) => getComputedStyle(child).display !== "none")
        .map((child) => child.getBoundingClientRect());
      return {
        width: n.getBoundingClientRect().width,
        height: n.getBoundingClientRect().height,
        overlap: boxes.some((box, i) => i > 0 && box.left < boxes[i - 1].right),
        inside: boxes.every((box) => box.left >= 0 && box.right <= innerWidth),
      };
    });
    expect(dimensions.overlap).toBe(false);
    expect(dimensions.inside).toBe(true);
    expect(dimensions.width).toBeLessThanOrEqual(1280);
    expect(dimensions.height).toBe(width >= 1240 ? 80 : 64);
    const glass = await page.locator(".site-nav").evaluate((node) => {
      const layer = getComputedStyle(node, "::before");
      const rect = node.getBoundingClientRect();
      return {
        radius: getComputedStyle(node).borderRadius,
        background: layer.backgroundColor,
        blur: layer.backdropFilter,
        left: rect.left,
        right: rect.right,
        top: rect.top,
      };
    });
    expect(glass.radius).toBe("9999px");
    expect(glass.blur).toContain("blur(18px)");
    expect(glass.background).toBe("rgba(255, 255, 255, 0.88)");
    expect(glass.left).toBeGreaterThanOrEqual(12);
    expect(glass.right).toBeLessThanOrEqual(width - 12);
    expect(glass.top).toBe(width >= 1240 ? 20 : 12);
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    ).toBe(true);
  }
  await page.screenshot({
    path: "test-results/navbar-desktop.png",
    animations: "disabled",
  });
});
test("floating navbar condenses at 48 pixels while its layout offset stays stable", async ({
  page,
}) => {
  await page.goto("/");
  await expect(page.locator("main h1")).toBeVisible();
  await expect(page.locator(".site-nav")).toHaveCSS("opacity", "1");
  const originalTop = await page
    .locator("main")
    .evaluate((node) => node.getBoundingClientRect().top + scrollY);
  const height = await page
    .locator(".site-header")
    .evaluate((n) => n.getBoundingClientRect().height);
  await page.evaluate(() => scrollTo(0, 40));
  await expect(page.locator(".site-header")).not.toHaveClass(/is-scrolled/);
  await page.evaluate(() => scrollTo(0, 60));
  await expect(page.locator(".site-header")).toHaveClass(/is-scrolled/);
  expect(
    await page
      .locator(".site-header")
      .evaluate((n) => n.getBoundingClientRect().top),
  ).toBe(20);
  expect(
    await page
      .locator(".site-header")
      .evaluate((n) => n.getBoundingClientRect().height),
  ).toBe(height);
  await expect(page.locator(".site-nav")).toHaveCSS("min-height", "74px");
  expect(
    await page
      .locator("main")
      .evaluate((node) => node.getBoundingClientRect().top + scrollY),
  ).toBe(originalTop);
  await expect
    .poll(() =>
      page
        .locator(".site-nav")
        .evaluate((node) => getComputedStyle(node, "::before").backgroundColor),
    )
    .toBe("rgba(255, 255, 255, 0.96)");
});
test("mobile backdrop dismisses, navigation closes and resize releases the focus trap", async ({
  page,
}) => {
  await page.setViewportSize({ width: 768, height: 1000 });
  await page.goto("/");
  await expect(page.locator("main h1")).toBeVisible();
  await page.evaluate(() => scrollTo(0, 200));
  await expect(page.locator(".site-header")).toHaveClass(/is-scrolled/);
  await page.getByRole("button", { name: "Open menu" }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page
    .locator(".mobile-menu-backdrop")
    .click({ position: { x: 10, y: 30 } });
  await expect(page.getByRole("dialog")).toHaveCount(0);
  expect(await page.evaluate(() => document.body.style.overflow)).toBe("");
  await page.getByRole("button", { name: "Open menu" }).click();
  await page.screenshot({
    path: "test-results/navbar-mobile-open.png",
    animations: "disabled",
  });
  await page
    .getByRole("dialog")
    .getByRole("link", { name: "Download App", exact: true })
    .click();
  await expect(page).toHaveURL(/\/download$/);
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await page.getByRole("button", { name: "Open menu" }).click();
  await page.setViewportSize({ width: 1280, height: 900 });
  await expect(page.getByRole("dialog")).toHaveCount(0);
  expect(await page.evaluate(() => document.body.style.overflow)).toBe("");
  await expect(page.locator("#main-content")).not.toHaveAttribute("inert", "");
});
