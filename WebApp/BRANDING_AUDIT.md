# Trivia identity and localisation audit

The authoritative supplied identity is **Trivia — Your Journey. Your Choice.**, developed for Zimbabwe by **MOrdec Solutions (Private) Limited**. The developer is not presented as the verified intellectual-property owner, and Trivia is not described as a separately incorporated company.

## Findings and changes

- No obsolete product branding was found in rendered public components. The development name is retained only as historical documentation; technical package names, endpoint contracts and persisted identifiers were preserved.
- Added developer attribution to the public footer, About copy and administration footer. No official developer logo was identified, so attribution is text.
- Centralised market defaults, official identity, supported language, page metadata, example cities, a prospective payment catalogue and separate empty operational availability lists in `src/config/project.ts`.
- Updated homepage supporting copy while retaining the approved headline, layout, fonts, colours, photographs, navigation and animations.
- Generate initial HTML metadata from the central configuration with Vite; update route titles, descriptions, Open Graph and Twitter text through the existing public layout. Added application-name and favicon title metadata. Structured data identifies software in development and its developer, without ratings, offers, addresses, download URLs or ownership claims. Canonical URLs are emitted only for a configured HTTPS site origin.
- Replaced Cape Town city photography in About and Contact with licensed Harare photography by Noah Denhe. Local 640px/1200px WebP files and credits include the source and licence. Other stock photographs remain illustrative, not evidence of a fleet, city coverage or endorsement.
- Currency formatting uses `en-ZW`, defaults to USD and accepts another backend-supplied currency. Existing trip displays accept an optional currency. Demo fare labels share their existing persisted keys through central defaults.
- Reusable date formatting fixes the display timezone to `Africa/Harare` through `Intl`, rejects ambiguous offset-free backend timestamps, and uses explicit UTC fixture instants. Admin settings show timezone, language and currency. No manual UTC-offset arithmetic was added.
- Reusable phone handling normalises local Zimbabwean mobile/fixed-line formats and international dialling formats. Profile and retained demo-contact forms validate before saving. The sample account has no prefilled telephone number; no official contact number was invented. This is format validation, not proof of number assignment or ownership.
- The prospective payment catalogue includes Cash, EcoCash, OneMoney, bank cards and bank transfers. No payment method is enabled as operational. Sample cash records remain labelled demonstrations; public pages process no payments.
- The existing router still has public information pages and a separate guarded admin portal. Historical passenger/driver modules remain unrouted; changes there only reuse localisation helpers. Admin authentication and role enforcement were preserved.
- App-store, authorised APK, social, support and contact destinations remain deployment configuration. No destination, launch date, operational coverage, regulatory approval, milestone, statistic, business address or customer testimonial was invented.

## Modified files

- Configuration and helpers: `src/config/project.ts`, `src/utils/format.ts`, `src/utils/localisation.ts`, `src/types/domain.ts`, `src/store/useAppStore.ts`, `src/services/mock.ts`.
- Shared shell: `src/components/layout/Footer.tsx`, `PublicLayout.tsx`, `AppLayout.tsx`.
- Shared UI: `src/components/ui/primitives.tsx`, `AppPreview.tsx`, `Photo.tsx`.
- Public content: `src/features/shared/Landing.tsx`, `PublicPages.tsx`, `Contact.tsx`, `publicContent.ts`, `marketing.css`, `src/typography.css` (localised metric widths and readable admin attribution).
- Admin and retained reusable flows: `src/features/auth/AuthPage.tsx`, `src/features/shared/SharedPages.tsx`, `src/features/admin/AdminPages.tsx`, `Operations.tsx`, `src/features/passenger/Booking.tsx`, `PassengerPages.tsx`, `src/features/driver/DriverPages.tsx`.
- Metadata and assets: `index.html`, `vite.config.ts`, `public/favicon.svg`, `public/photos/credits.json`, `public/photos/harare-{640,1200}.webp`. Removed the superseded Cape Town image variants.
- Documentation and tests: `README.md`, this audit, `tests/localisation.spec.ts`.

## Scope and verification boundaries

All changes are inside WebApp. MobileApp and Backend are unchanged. Backend authentication tests use explicit mocked responses and the existing development-only demo; they do not prove a live Django deployment, operational payment provider, contact delivery or published app-store listing.

Photograph source: https://www.pexels.com/photo/high-rise-building-with-glass-panels-along-a-street-13408426/
Licence: https://www.pexels.com/license/
Phone plan reference: https://www.ituob.org/issues/1108-en/ (POTRAZ communication).

## Verified results

- `npm run lint`: passed.
- `npm run build`: TypeScript and production compilation passed on the final source.
- Full automated run exercised 36 checks: 34 passed initially. It found an overly strict date-punctuation assertion and 320px metric overflow caused by the longer localised USD prefix. Both were corrected; the final affected localisation/typography suite passed **9/9**.
- Public routes, removed customer/driver routes, sticky/floating navbar, menus and focus handling, fly-in and reduced-motion behaviour, FAQs, configured/unavailable download behaviour, Android/iPhone detection, contact-draft validation, admin demo management and production authentication guards were covered.
- All nine public pages passed branding/metadata and 320px/1440px checks. The visual sweep checked desktop/mobile photo loading and absence of the forbidden navy colours. Public and admin screenshots were reviewed. Final admin currency labels and developer attribution fit at 320px.
- Production HTML was checked before JavaScript execution for the exact homepage title, description, application name, developer metadata and development-status structured data.
- Phone validation, international normalisation, configurable currency output and date rollover across Harare midnight passed. A demo settings submission confirmed that the normalised phone value is saved.
- No obsolete development branding or incorrect developer spelling remains in visible website content. The historical development name remains only in explanatory documentation.
