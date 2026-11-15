import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { projectConfig, productStructuredData } from "./src/config/project.ts";
export default defineConfig(({ mode }) => {
  const variables = loadEnv(mode, process.cwd(), "VITE_");
  let origin = "";
  try {
    const url = new URL(variables.VITE_SITE_URL);
    if (url.protocol === "https:") origin = url.origin;
  } catch {
    /* No invented canonical domain. */
  }
  return {
    plugins: [
      react(),
      tailwindcss(),
      {
        name: "trivia-public-sitemap",
        transformIndexHtml() {
          return [
            {
              tag: "title",
              children: projectConfig.homeTitle,
              injectTo: "head",
            },
            ...[
              ["name", "description", projectConfig.metaDescription],
              ["name", "application-name", projectConfig.productName],
              ["name", "apple-mobile-web-app-title", projectConfig.productName],
              ["name", "author", projectConfig.developer],
              ["property", "og:title", projectConfig.homeTitle],
              ["property", "og:description", projectConfig.metaDescription],
              ["property", "og:site_name", projectConfig.productName],
              ["property", "og:locale", projectConfig.locale.replace("-", "_")],
              ["name", "twitter:card", "summary"],
              ["name", "twitter:title", projectConfig.homeTitle],
              ["name", "twitter:description", projectConfig.metaDescription],
            ].map(([attribute, key, content]) => ({
              tag: "meta",
              attrs: { [attribute]: key, content },
              injectTo: "head" as const,
            })),
            {
              tag: "script",
              attrs: {
                type: "application/ld+json",
                id: "trivia-product-metadata",
              },
              children: JSON.stringify(productStructuredData).replace(
                /</g,
                "\\u003c",
              ),
              injectTo: "head",
            },
            ...(origin
              ? [
                  {
                    tag: "link",
                    attrs: { rel: "canonical", href: `${origin}/` },
                    injectTo: "head" as const,
                  },
                  {
                    tag: "meta",
                    attrs: { property: "og:url", content: `${origin}/` },
                    injectTo: "head" as const,
                  },
                ]
              : []),
          ];
        },
        generateBundle() {
          if (!origin) return;
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
          this.emitFile({
            type: "asset",
            fileName: "sitemap.xml",
            source: `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${routes.map((path) => `<url><loc>${origin}${path}</loc></url>`).join("")}</urlset>`,
          });
          this.emitFile({
            type: "asset",
            fileName: "robots.txt",
            source: `User-agent: *\nAllow: /\nDisallow: /admin\nSitemap: ${origin}/sitemap.xml\n`,
          });
        },
      },
    ],
  };
});
