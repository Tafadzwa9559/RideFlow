import { test, expect } from "@playwright/test";
test.use({ baseURL: "http://127.0.0.1:4225" });
test("production offers no demo bypass and rejects client-forged admin state", async ({
  page,
}) => {
  await page.addInitScript(() =>
    localStorage.setItem(
      "trivia-demo-v1",
      JSON.stringify({
        state: { user: { role: "admin", firstName: "Forged" } },
        version: 0,
      }),
    ),
  );
  await page.goto("/admin/dashboard");
  await expect(page).toHaveURL(/\/admin\/login$/);
  await expect(
    page.getByRole("button", { name: "Open admin demo" }),
  ).toHaveCount(0);
  await expect(
    page.getByText("Live sign-in is unavailable.", { exact: false }),
  ).toBeVisible();
  await page
    .getByLabel("Email address", { exact: true })
    .fill("admin@example.test");
  await page.getByLabel("Password", { exact: true }).fill("samplepass123");
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.getByRole("alert")).toContainText("not configured");
  await expect(page).toHaveURL(/\/admin\/login$/);
});
