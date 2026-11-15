import { expect, test, type Page } from "@playwright/test";
async function settled(page: Page, path: string) {
  const region = page.locator(`.public-page[data-page="${path}"]`);
  await expect(region).toBeVisible();
  await expect(region.locator("h1")).toBeVisible();
  await expect
    .poll(() => region.evaluate((node) => getComputedStyle(node).opacity))
    .toBe("1");
}
test("sticky header and shared shell survive outgoing and incoming page transitions", async ({
  page,
}) => {
  await page.goto("/");
  await settled(page, "/");
  await page
    .locator(".site-header")
    .evaluate((n) => n.setAttribute("data-retained", "yes"));
  await page
    .locator(".site-footer")
    .evaluate((n) => n.setAttribute("data-retained", "yes"));
  await page.evaluate(() => scrollTo(0, 1100));
  await expect(page.locator(".site-header")).toHaveClass(/is-scrolled/);
  expect(
    await page
      .locator(".site-header")
      .evaluate((n) => n.getBoundingClientRect().top),
  ).toBe(20);
  await page
    .getByRole("link", { name: "Ride With Trivia", exact: true })
    .click();
  await expect(page.locator('.public-page[data-page="/"]')).toHaveAttribute(
    "inert",
    "",
  );
  await settled(page, "/ride");
  await expect(page.locator("main h1")).toHaveText(
    "Everyday plans. A better way to get there.",
  );
  expect(await page.evaluate(() => scrollY)).toBe(0);
  await expect(page.locator(".site-header")).toHaveAttribute(
    "data-retained",
    "yes",
  );
  await expect(page.locator(".site-footer")).toHaveAttribute(
    "data-retained",
    "yes",
  );
  await expect(
    page.getByRole("link", { name: "Ride With Trivia", exact: true }),
  ).toHaveAttribute("aria-current", "page");
});
test("history restores independent scroll positions in both directions", async ({
  page,
}) => {
  await page.goto("/");
  await settled(page, "/");
  await page.evaluate(() => scrollTo(0, 1500));
  await page
    .getByRole("link", { name: "Ride With Trivia", exact: true })
    .click();
  await settled(page, "/ride");
  await page.evaluate(() => scrollTo(0, 650));
  await page.getByRole("link", { name: "Safety", exact: true }).click();
  await settled(page, "/safety");
  await page.goBack();
  await settled(page, "/ride");
  await expect.poll(() => page.evaluate(() => scrollY)).toBe(650);
  await page.goBack();
  await settled(page, "/");
  await expect.poll(() => page.evaluate(() => scrollY)).toBe(1500);
  await page.goForward();
  await settled(page, "/ride");
  await expect.poll(() => page.evaluate(() => scrollY)).toBe(650);
});
test("dropdown supports arrow keys, Escape, outside click and an offset section link", async ({
  page,
}) => {
  await page.goto("/");
  await settled(page, "/");
  const more = page.getByRole("button", { name: "More", exact: true });
  await more.focus();
  await page.keyboard.press("ArrowDown");
  await expect(
    page.getByRole("link", { name: "Contact & Support", exact: true }).first(),
  ).toBeFocused();
  await page.keyboard.press("ArrowDown");
  await expect(page.locator(".dropdown-panel a").nth(1)).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(more).toBeFocused();
  await expect(more).toHaveAttribute("aria-expanded", "false");
  await more.click();
  await page.locator("main h1").click();
  await expect(more).toHaveAttribute("aria-expanded", "false");
  await more.click();
  await page.getByRole("link", { name: "Why Trivia", exact: true }).click();
  await expect(page).toHaveURL(/#why-trivia$/);
  await expect
    .poll(async () => {
      const anchor = await page.locator("#why-trivia").boundingBox();
      const navigation = await page.locator(".site-nav").boundingBox();
      if (!anchor || !navigation) return false;
      const gap = anchor.y - (navigation.y + navigation.height);
      return gap >= 16 && gap <= 40;
    })
    .toBe(true);
});
test("mobile dialog traps focus, locks scrolling and restores focus on dismiss", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  await settled(page, "/");
  const trigger = page.getByRole("button", { name: "Open menu" });
  await trigger.click();
  const dialog = page.getByRole("dialog", { name: "Mobile navigation" });
  await expect(dialog).toBeVisible();
  expect(await page.evaluate(() => document.body.style.overflow)).toBe(
    "hidden",
  );
  await expect(
    dialog.getByRole("button", { name: "Close navigation menu" }),
  ).toBeFocused();
  await page.keyboard.press("Shift+Tab");
  await expect(
    dialog.getByRole("link", { name: "Download App", exact: false }),
  ).toBeFocused();
  await page.keyboard.press("Tab");
  await expect(
    dialog.getByRole("button", { name: "Close navigation menu" }),
  ).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(dialog).toHaveCount(0);
  await expect(trigger).toBeFocused();
  expect(await page.evaluate(() => document.body.style.overflow)).toBe("");
  await trigger.click();
  await page
    .getByRole("dialog")
    .getByRole("link", { name: "Safety", exact: true })
    .click();
  await settled(page, "/safety");
  await expect(page.getByRole("dialog")).toHaveCount(0);
  await expect(page.locator("main")).not.toHaveAttribute("inert", "");
});
test("FAQ reveals one answer at a time and remains keyboard operable", async ({
  page,
}) => {
  await page.goto("/faq");
  await settled(page, "/faq");
  const questions = page.locator(".site-faq-list h3 button");
  await questions.nth(0).focus();
  await page.keyboard.press("Enter");
  await expect(questions.nth(0)).toHaveAttribute("aria-expanded", "true");
  await expect(page.locator('.faq-item [role="region"]')).toHaveCount(1);
  await questions.nth(1).click();
  await expect(questions.nth(0)).toHaveAttribute("aria-expanded", "false");
  await expect(page.locator('.faq-item [role="region"]')).toHaveCount(1);
  await questions.nth(1).press("Space");
  await expect(page.locator('.faq-item [role="region"]')).toHaveCount(0);
});
test("all requested viewport widths fit and navigation remains usable", async ({
  page,
}) => {
  for (const width of [320, 375, 390, 430, 768, 1024, 1280, 1440, 1680]) {
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/");
    await settled(page, "/");
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth,
      ),
    ).toBe(true);
    if (await page.getByRole("button", { name: "Open menu" }).isVisible()) {
      await page.getByRole("button", { name: "Open menu" }).click();
      await page
        .getByRole("dialog")
        .getByRole("link", { name: "About Us", exact: true })
        .click();
    } else
      await page
        .getByRole("navigation", { name: "Main navigation" })
        .getByRole("link", { name: "About Us", exact: true })
        .click();
    await settled(page, "/about");
    await expect(page.locator("main h1")).toHaveText(
      "A local beginning. A wider horizon.",
    );
  }
});
test("reduced motion, rapid navigation and download availability produce no runtime errors", async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("/");
  await settled(page, "/");
  await page
    .getByRole("link", { name: "Ride With Trivia", exact: true })
    .click();
  await page.getByRole("link", { name: "Safety", exact: true }).click();
  await settled(page, "/safety");
  await expect(page.locator("main h1")).toHaveText(
    "A shared approach to safer journeys.",
  );
  await page.getByRole("link", { name: "Download App", exact: true }).click();
  await settled(page, "/download");
  await expect(
    page.getByRole("button", { name: "Download for iPhone — Coming soon" }),
  ).toBeDisabled();
  const position = await page
    .locator(".public-page")
    .evaluate((n) => getComputedStyle(n).transform);
  expect(["none", "matrix(1, 0, 0, 1, 0, 0)"]).toContain(position);
  expect(errors).toEqual([]);
});
