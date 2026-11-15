import { defineConfig } from "@playwright/test";
export default defineConfig({
  testDir: "./tests",
  timeout: 60000,
  fullyParallel: true,
  workers: 2,
  use: {
    baseURL: "http://127.0.0.1:5215",
    headless: true,
    launchOptions: {
      executablePath:
        process.env.PLAYWRIGHT_CHROME_PATH || "/usr/bin/google-chrome",
      args: ["--no-sandbox"],
    },
  },
  webServer: [
    {
      command: "npm run dev -- --host 127.0.0.1 --port 5215 --strictPort",
      url: "http://127.0.0.1:5215",
      reuseExistingServer: false,
      env: {
        VITE_ENABLE_ADMIN_DEMO: "true",
        VITE_API_BASE_URL: "http://127.0.0.1:8000/api",
      },
    },
    {
      command: "npm run preview -- --host 127.0.0.1 --port 4225 --strictPort",
      url: "http://127.0.0.1:4225",
      reuseExistingServer: false,
    },
  ],
  reporter: "list",
});
