import { test, expect } from "@playwright/test";

test("directional entrances reveal once and retain their final state after scrolling away", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto("/");
  const text = page.locator('.passenger-editorial > [data-reveal="left"]');
  const photo = page.locator('.passenger-editorial > [data-reveal="right"]');
  await expect(text).toHaveCSS("opacity", "0");
  expect(
    await text.evaluate(
      (node) => new DOMMatrix(getComputedStyle(node).transform).m41,
    ),
  ).toBe(-60);
  expect(
    await photo.evaluate(
      (node) => new DOMMatrix(getComputedStyle(node).transform).m41,
    ),
  ).toBe(70);
  await text.scrollIntoViewIfNeeded();
  await expect(text).toHaveCSS("opacity", "1");
  await expect(photo).toHaveCSS("opacity", "1");
  await expect
    .poll(() =>
      text.evaluate(
        (node) => new DOMMatrix(getComputedStyle(node).transform).m41,
      ),
    )
    .toBe(0);
  await page.evaluate(() => scrollTo(0, 0));
  await expect(text).toHaveCSS("opacity", "1");
  await text.scrollIntoViewIfNeeded();
  await expect(text).toHaveCSS("opacity", "1");
  await expect(page.locator("[data-parallax]")).toHaveCount(1);
  const image = page.locator(".hero-photograph img");
  await expect(image).toBeVisible();
  expect(
    await image.evaluate((node) => node.getBoundingClientRect().height),
  ).toBeGreaterThan(200);
  expect(errors).toEqual([]);
});

test("mobile fly-in distances are capped and do not create horizontal overflow", async ({
  page,
}) => {
  for (const width of [320, 390, 768]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/");
    const photo = page.locator('.passenger-editorial > [data-reveal="right"]');
    await expect(photo).toHaveCSS("opacity", "0");
    const offset = await photo.evaluate(
      (node) => new DOMMatrix(getComputedStyle(node).transform).m41,
    );
    expect(offset).toBe(width <= 760 ? 24 : 70);
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    ).toBe(true);
    await photo.scrollIntoViewIfNeeded();
    await expect(photo).toHaveCSS("opacity", "1");
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    ).toBe(true);
  }
});

test("reduced motion immediately exposes off-screen content and removes parallax", async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
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
    await expect(page.locator("[data-parallax]")).toHaveCount(0);
    const states = await page.locator("[data-reveal]").evaluateAll((nodes) =>
      nodes.every((node) => {
        const style = getComputedStyle(node);
        return (
          style.opacity === "1" &&
          (style.transform === "none" ||
            new DOMMatrix(style.transform).isIdentity)
        );
      }),
    );
    expect(states).toBe(true);
  }
});
