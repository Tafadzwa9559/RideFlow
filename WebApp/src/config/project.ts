/** Authoritative public identity. Deployment destinations stay in env.ts. */
export const projectConfig = Object.freeze({
  productName: "Trivia",
  tagline: "Your Journey. Your Choice.",
  category: "Ride-hailing and mobility",
  country: "Zimbabwe",
  countryCode: "ZW",
  dialCode: "+263",
  timezone: "Africa/Harare",
  language: "en",
  locale: "en-ZW",
  languageName: "English",
  defaultCurrency: "USD",
  developer: "MOrdec Solutions (Private) Limited",
  status: "in-development",
  heroHeadline: "Your City. Your Ride. Your Choice.",
  heroDescription:
    "Experience a smarter way to move around Zimbabwe. Discover flexible fares, connect with drivers, and take greater control of your journey.",
  developmentNotice:
    "Trivia is in development. Launch timing and service coverage have not yet been confirmed.",
  homeTitle: "Trivia | Ride-Hailing in Zimbabwe",
  metaDescription:
    "Discover Trivia, a ride-hailing platform developed for Zimbabwe by MOrdec Solutions (Private) Limited. Explore flexible rides, driver opportunities, and the Trivia mobile app.",
});

// Add reviewed translation catalogues here before exposing language choices.
export const supportedLanguages = [projectConfig.language] as const;
export const cityExamples = [
  "Harare",
  "Bulawayo",
  "Mutare",
  "Gweru",
  "Masvingo",
  "Chitungwiza",
  "Norton",
] as const;
export const paymentMethods = [
  { id: "cash", label: "Cash" },
  { id: "ecocash", label: "EcoCash" },
  { id: "onemoney", label: "OneMoney" },
  { id: "card", label: "Bank cards" },
  { id: "bank-transfer", label: "Bank transfers" },
] as const;
export type PaymentMethod = (typeof paymentMethods)[number]["id"];
/** Populate only from verified operational configuration, never from example cities. */
export const serviceAvailability: {
  readonly coverageCities: readonly string[];
  readonly enabledPaymentMethods: readonly PaymentMethod[];
} = Object.freeze({ coverageCities: [], enabledPaymentMethods: [] });

export const publicMetadata: Record<string, readonly [string, string]> = {
  "/terms": [
    "Terms & Conditions | Trivia",
    "Review Trivia’s draft Terms & Conditions for passengers and drivers in Zimbabwe.",
  ],
  "/privacy": [
    "Privacy Policy | Trivia",
    "Review Trivia’s draft Privacy Policy and the information used for passenger and driver services.",
  ],
  "/": [projectConfig.homeTitle, projectConfig.metaDescription],
  "/how-it-works": [
    "How It Works | Trivia",
    "Discover the planned passenger and driver journeys in Trivia, a mobile mobility platform in development for Zimbabwe.",
  ],
  "/ride": [
    "Ride With Trivia | Zimbabwe",
    "Explore the planned passenger experience in Zimbabwe: flexible fares, driver choice and clear journey details. Trivia is in development.",
  ],
  "/drive": [
    "Drive With Trivia | Zimbabwe",
    "Learn about planned driver onboarding and driving opportunities in Zimbabwe. Eligibility, launch timing and availability are not yet confirmed.",
  ],
  "/safety": [
    "Safety | Trivia",
    "Learn about Trivia’s planned safety approach, driver review and shared responsibilities. Safety capabilities are in development.",
  ],
  "/about": [
    "About Trivia | Zimbabwe",
    `Trivia is a ride-hailing technology platform in development for Zimbabwe by ${projectConfig.developer}.`,
  ],
  "/contact": [
    "Contact & Support | Trivia",
    "Find confirmed Trivia contact channels and enquiry options when available. This website is not an emergency service.",
  ],
  "/download": [
    "Download Trivia | Android & iPhone",
    "Check official Trivia Android and iPhone release destinations. Unavailable versions are marked Coming Soon; ride-service availability is not yet confirmed.",
  ],
  "/faq": [
    "FAQs | Trivia",
    "Answers about Trivia’s planned Zimbabwean mobile experience, fares, payments, safety and release availability.",
  ],
};

export const productStructuredData = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: projectConfig.productName,
  applicationCategory: "TravelApplication",
  operatingSystem: "Android, iOS",
  inLanguage: projectConfig.language,
  description: `${projectConfig.metaDescription} ${projectConfig.developmentNotice}`,
  creator: {
    "@type": "Organization",
    name: projectConfig.developer,
    description: "Zimbabwean technology company",
  },
};

export const demoFareRules: Record<string, number> = {
  [`Standard minimum fare (${projectConfig.defaultCurrency})`]: 3,
  [`Comfort minimum fare (${projectConfig.defaultCurrency})`]: 5,
  [`XL minimum fare (${projectConfig.defaultCurrency})`]: 7,
  [`Base fare (${projectConfig.defaultCurrency})`]: 2,
  [`Per kilometre (${projectConfig.defaultCurrency})`]: 0.8,
  [`Cancellation fee (${projectConfig.defaultCurrency})`]: 0,
};
