# Trivia WebApp

Trivia’s React application now contains the public mobile-app website and an administrator portal. Passenger and driver ride/account functionality belongs exclusively in the separate Flutter application. This refactor changes only `WebApp`.

## Official identity and localisation

Trivia — **Your Journey. Your Choice.** — is a ride-hailing and mobility application being developed for Zimbabwe by **MOrdec Solutions (Private) Limited**, a Zimbabwean technology company. Trivia is the consumer brand; no separate incorporation, ownership, offices, approvals, launch dates or operational coverage are asserted. The former development name is RideFlow; technical paths and identifiers are retained where appropriate.

`src/config/project.ts` is the authoritative identity, English metadata and market configuration. English is the only supported language; add reviewed translation catalogues before exposing Shona or Ndebele. Example cities are separate from the empty verified coverage list. The payment-method catalogue includes Cash, EcoCash, OneMoney, bank cards and bank transfers; the enabled-method list is empty. Sample cash records are explicitly demonstrations.

The wider project uses Flutter (Android/iOS), Django REST Framework, MySQL and Django Channels/WebSockets. These are architectural details, not evidence of live integration.

`src/utils/format.ts` formats amounts using `en-ZW`, USD by default, with an optional backend-provided currency. `src/utils/localisation.ts` formats timezone-aware instants using `Africa/Harare`; ambiguous timestamps without offsets display as unavailable. Sample dates use explicit UTC instants. No manual UTC+2 arithmetic is used. Phone input accepts Zimbabwe mobile/fixed-line formats and international E.164 structure, normalises to a country-prefixed number, and does not claim number ownership verification. No official support phone number is invented.

SEO is generated from the same project configuration for dev and production via Vite, then updated per public route. Structured data declares an application **in development** and its developer only, with no reviews, pricing, app-store URLs or business address. Canonical and Open Graph URLs require the verified `VITE_SITE_URL`. Developer attribution does not assert intellectual-property ownership.

The About and Contact pages use Noah Denhe’s licensed Harare city-centre photography; the remaining stock photographs are illustrative and do not portray Trivia operations. Original logo artwork was not found in WebApp, so developer attribution uses text.

## Run

```sh
cd WebApp
npm install
cp .env.example .env
npm run dev
```

Use the URL printed by Vite. Node 22.12+ is required. For a static deployment, configure fallback to `index.html` so client routes work on reload.

## Public routes

`/`, `/how-it-works`, `/ride`, `/drive`, `/safety`, `/about`, `/contact`, `/download`, `/faq`.

There is no public account login, registration, booking form, passenger dashboard or driver dashboard. Former `/passenger`, `/driver` and `/auth/*` routes reach the 404 page. The footer has a discreet `/admin/login` link.

## Release and contact configuration

Set only verified official destinations:

- `VITE_ANDROID_APP_URL`: official Google Play listing.
- `VITE_IOS_APP_URL`: official Apple App Store listing.
- `VITE_OFFICIAL_APK_URL`: HTTPS APK destination; requires `VITE_OFFICIAL_APK_VERIFIED=true` after release-owner verification. The Play listing takes precedence.
- `VITE_SUPPORT_EMAIL`: confirmed public email address.
- `VITE_CONTACT_API_URL`: HTTPS contact endpoint accepting `{name,email,topic,message}`. Configure CORS/rate limiting/spam controls on that service. When absent, the form validates a draft and explicitly says it has not been sent.
- `VITE_SOCIAL_URL`: confirmed social link.
- `VITE_SITE_URL`: public HTTPS site URL. Enables canonical links and build-generated sitemap/robots sitemap reference. No domain is fabricated when absent.

Empty or invalid app destinations display disabled **Coming soon** controls. Device detection suggests Android or iOS (including touch-enabled iPad desktop identification), supports manual override, and never starts a download automatically. Both audiences use the same application destinations. Release availability and live ride availability are kept separate.

## Administrator access

Routes: `/admin/login`, `/admin/dashboard`, `/admin/passengers`, `/admin/drivers`, `/admin/verification`, `/admin/vehicles`, `/admin/rides`, `/admin/payments`, `/admin/disputes`, `/admin/analytics`, `/admin/notifications`, `/admin/settings`. `/admin` redirects to the dashboard, and `/admin/fares` remains a fare configuration shortcut.

Live authentication uses proposed Django `/auth/token/`, `/auth/token/refresh/`, `/auth/logout/` and `/users/me/` contracts configured through `VITE_API_BASE_URL`. A verified `role: "admin"` from the authenticated backend is required. JWT access tokens and current sessions are held in memory. Persisted legacy demo users cannot authorise the portal. Refresh assumes a secure HttpOnly cookie contract; the backend must implement CSRF protection, CORS, role enforcement and revocation. Backend-authoritative live management data is not yet connected, so authenticated live sessions see an explicit unconfigured state rather than sample controls presented as operational tools.

To review the implemented sample management interfaces locally, set `VITE_ENABLE_ADMIN_DEMO=true` in `.env` and restart Vite. `/admin/login` then offers **Open admin demo**. This bypass is guarded by both `import.meta.env.DEV` and the explicit flag; production builds cannot enable it. The demo session ends on a full reload and never writes to Django. Mock driver decisions, fare configuration and shared notices persist in the existing demo store; directories, vehicle notes and dispute actions remain session-local as labeled.

Sample interfaces cover overview metrics/charts/events, searchable passenger/driver/vehicle directories, application decisions with reason validation and explicit confirmation, ride filtering/detail, payment monitoring, dispute resolution with confirmation, analytics, notifications and profile/fare settings. Private verification documents are not fabricated or exposed.

## Integration structure

Existing `components/`, `pages/`, `features/`, `hooks/`, `store/`, `services/`, `types/` and routing locations are reused. Historical passenger/driver source is retained as unrouted reference code; shared trip tables remain reusable for administration. There is one routed administrator account portal.

Typed API adapters remain under `src/services/api/` for auth, users, drivers, vehicles, rides, offers, payments, analytics and notifications. The disconnected Channels client remains in `src/services/realtime.ts`. Application endpoints, serialization, document storage, payment providers, operational reporting and authoritative permission/state enforcement require Django integration. No Backend or MobileApp files were changed.

Public pages use a clearly labeled, code-native illustrative phone concept rather than a fabricated app screenshot. The redesigned public pages use eight licensed Pexels photographs, served locally as responsive 640px and 1200px WebP assets. Source pages, photographer credits and license links are recorded in `public/photos/credits.json` and linked from the footer. Photography is illustrative and does not depict a claimed Trivia driver, customer or operating location.

## Validation

```sh
npm run lint
npm run build
npm run test:e2e
```

Lint uses the existing Oxlint configuration. The build includes TypeScript validation. Browser tests start isolated Vite development and production-preview servers on ports 5215 and 4215. Build before running them; do not use a production `.env` with real destinations for fixtures. The test dev server explicitly enables its sample admin flow. Override `PLAYWRIGHT_CHROME_PATH` if Chrome is not at `/usr/bin/google-chrome`.

The marketing pages set route titles/descriptions/Open Graph text, use semantic HTML and accessible navigation, lazy-load the locally served photo, and support reduced motion. `robots.txt` excludes admin routes; admin login and public 404 routes set noindex. Search engines that do not execute JavaScript see the homepage metadata; full per-route server-rendered SEO would require deployment prerendering.

## Public interaction system

`PageTransition` uses the installed Motion library and React Router outlets to fade outgoing pages (220 ms) and reveal incoming pages (440 ms). Shared navigation and footer stay mounted. Public informational routes receive an explicit pathname so the outgoing content stays stable during its exit. Incoming content has its own Suspense boundary, and content receives focus after navigation unless the visitor is already interacting with it or a menu.

`ScrollToTop` resets new pages before paint, applies sticky-header offsets for hash navigation, and restores recorded positions for Back/Forward history entries. A bounded history-entry map prevents unbounded growth. Native automatic restoration is disabled only while the public layout is mounted.

`ScrollReveal` reveals section groups once as they enter the viewport. Motion preferences disable movement and shorten transitions; the page progress line is hidden for reduced motion. Buttons/cards use restrained hover and press feedback without adding click behavior to informational cards.

The sticky header keeps a stable height and changes its background/shadow after scrolling. Its More disclosure supports arrows, Home/End, Escape, focus departure and outside click. Mobile navigation has an animated backdrop/dialog, scroll locking, background inertness, focus containment, Escape/outside dismissal, breakpoint cleanup and focus return. FAQs use a reusable animated accordion with one open answer per group.

The interaction suite verifies sticky behavior, shared shell persistence, outgoing/incoming content, scroll restoration in both history directions, offset anchors, keyboard controls, menu focus/scroll locking, reduced motion, rapid navigation and widths 320/375/390/430/768/1024/1440/1680. Existing public, download and admin regression checks are retained.

## Photography-led visual redesign

All nine public pages use a white/off-white, charcoal and restrained emerald palette. Editorial split layouts, numbered journeys, generous spacing and responsive photographs replace the former dark panels and repeated card grids. Administration uses white surfaces, neutral tables and emerald actions. The shared sticky navigation, download configuration, validation, route transitions and protected admin boundaries remain in place. No runtime dependencies were added for this redesign.

`Photo.tsx` centralizes responsive image sizing, loading priority and descriptive alternative text. Hero media loads eagerly; lower content loads lazily. Photos are illustrative, with no implied endorsement or claim that Trivia operates in the depicted city. The mobile product preview remains explicitly illustrative.

`tests/visual.spec.ts` checks every public route at desktop and mobile sizes, decodes its photography, checks overflow and prohibited navy colors, and captures review screenshots. Existing journey and interaction suites cover downloads, navigation, keyboard controls, history, forms and administrative access.

## Directional scroll animations

The existing `ScrollReveal` supports `direction` (`left`, `right`, `up`, `down`, `none`), `delay`, `duration`, `distance`, `once`, semantic `as`, `className` and children. `useInView` controls entrances independently of route transitions. Reveals run once per mounted page by default, retain layout space, and immediately reveal a group receiving keyboard focus. Delays are capped at 300ms; responsive CSS limits movement to 24px on phones. Reduced motion exposes all content immediately without transforms.

Public text, photos, category cards, timelines, FAQs and download options reuse this primitive. Repeated items have short index-based staggers. Broad sections only fade; their major content groups provide directional movement. The homepage hero coordinates its heading, supporting copy, buttons and photograph. Only the homepage vehicle photo and About city photo use an 8px scroll-linked parallax drift, with clipped overscan; reduced motion removes those scroll subscriptions. Existing navigation and admin interactions are retained.

`tests/animations.spec.ts` checks actual off-screen offsets, viewport triggers, final visibility after scrolling away and back, mobile distances/overflow and reduced-motion behavior across all nine pages. The visual suite scrolls every public page and checks that all reveal groups finish visible.

## Floating glass navigation

The existing navbar is a fixed, centered capsule (maximum 1280px), with 20px desktop or 12px mobile top margins. Its reserved page offset remains stable while the capsule becomes slightly shorter after 48px of scroll. A separate pseudo-element provides white glass, an 18px backdrop blur, subtle border and shadow, with an opaque white fallback. The glass and entrance transforms never enclose the fixed mobile overlay.

Desktop navigation switches to the existing accessible mobile dialog below 1240px; below 360px the header CTA moves into that dialog. Navigation, route-aware indicators, the More disclosure, focus trapping, scroll locking, Escape and outside dismissal retain their original behavior. The capsule entrance plays once per public-layout mount and respects reduced motion. Downloads still use the existing `/download` route and configured platform destinations. No runtime dependencies were added.
