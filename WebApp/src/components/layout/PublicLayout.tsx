import ScrollToTop from "../common/ScrollToTop";
import { projectConfig, publicMetadata } from "../../config/project";
import { env } from "../../config/env";
import { Suspense, useEffect, useLayoutEffect } from "react";
import { AnimatePresence } from "motion/react";
import PageTransition from "../common/PageTransition";
import { rememberScroll } from "../../utils/scrollPositions";
import LoadingSpinner from "../common/LoadingSpinner";
import { useLocation, useOutlet, useNavigationType } from "react-router-dom";
import Navbar from "./Navbar";
import Footer from "./Footer";
import "../../features/shared/marketing.css";
export default function PublicLayout() {
  const location = useLocation();
  const { pathname, hash } = location;
  const outlet = useOutlet();
  const action = useNavigationType();
  useLayoutEffect(() => () => rememberScroll(location.key), [location.key]);
  useLayoutEffect(() => {
    const previous = history.scrollRestoration;
    history.scrollRestoration = "manual";
    return () => {
      history.scrollRestoration = previous;
    };
  }, []);
  useEffect(() => {
    const [title, description] = publicMetadata[pathname] || [
      "Page Not Found | Trivia",
      "Find your way back to Trivia.",
    ];
    document
      .querySelector('meta[name="robots"]')
      ?.setAttribute(
        "content",
        publicMetadata[pathname] ? "index, follow" : "noindex, follow",
      );
    if (env.siteUrl && publicMetadata[pathname]) {
      let canonical = document.querySelector<HTMLLinkElement>(
        'link[rel="canonical"]',
      );
      if (!canonical) {
        canonical = document.createElement("link");
        canonical.rel = "canonical";
        document.head.append(canonical);
      }
      canonical.href = new URL(pathname, env.siteUrl).href;
    } else {
      document.querySelector('link[rel="canonical"]')?.remove();
    }
    document.title = title;
    document.documentElement.lang = projectConfig.language;
    document
      .querySelector('meta[name="description"]')
      ?.setAttribute("content", description);
    document
      .querySelector('meta[property="og:title"]')
      ?.setAttribute("content", document.title);
    document
      .querySelector('meta[property="og:description"]')
      ?.setAttribute("content", description);
    document
      .querySelector('meta[name="twitter:title"]')
      ?.setAttribute("content", document.title);
    document
      .querySelector('meta[name="twitter:description"]')
      ?.setAttribute("content", description);
    let socialUrl = document.querySelector<HTMLMetaElement>(
      'meta[property="og:url"]',
    );
    if (env.siteUrl && publicMetadata[pathname]) {
      if (!socialUrl) {
        socialUrl = document.createElement("meta");
        socialUrl.setAttribute("property", "og:url");
        document.head.append(socialUrl);
      }
      socialUrl.content = new URL(pathname, env.siteUrl).href;
    } else socialUrl?.remove();
  }, [pathname, hash]);
  return (
    <div className="marketing">
      <a className="skip-link" href="#main-content">
        Skip to content
      </a>
      <Navbar />
      <main id="main-content" tabIndex={-1}>
        <AnimatePresence mode="wait" initial={false}>
          <PageTransition key={pathname} location={location} action={action}>
            <Suspense fallback={<LoadingSpinner />}>
              <ScrollToTop location={location} action={action} />
              {outlet}
            </Suspense>
          </PageTransition>
        </AnimatePresence>
      </main>
      <Footer />
    </div>
  );
}
