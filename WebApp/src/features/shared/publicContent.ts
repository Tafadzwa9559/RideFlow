import { projectConfig } from "../../config/project";
export const passengerSteps = [
  "Download Trivia",
  "Create an account in the app",
  "Enter pickup and destination",
  "Choose or propose a fare",
  "Review driver offers",
  "Choose your driver",
  "Enjoy your ride",
];
export const driverSteps = [
  "Download Trivia",
  "Register as a driver in the app",
  "Submit required verification documents",
  "Wait for account approval",
  "Receive ride requests",
  "Negotiate fares and accept trips",
  "Complete rides and monitor earnings",
];
export const questions: [string, string][] = [
  [
    "Is Trivia available for real rides?",
    "The platform is in development. Service launch areas and availability have not yet been confirmed. This website introduces the planned mobile experience; it does not accept ride requests.",
  ],
  [
    "Can I book a ride on this website?",
    "Ride requests, fare negotiation, trip tracking and account management belong in the Flutter mobile app. This website provides information and official download destinations when available.",
  ],
  [
    "Where can I download the app?",
    "Visit the download page for the configured official Google Play or Apple App Store listing. If no official link is configured, the platform is marked Coming soon. Downloads never start automatically.",
  ],
  [
    "Do drivers need a different app?",
    "The planned Trivia application supports both passengers and drivers. Both download buttons lead to the same official application destination for your device.",
  ],
  [
    "How do flexible fares work?",
    "The planned experience lets passengers propose a fare and review driver offers. A fare is agreed before the journey; live rules will be confirmed at launch.",
  ],
  [
    "What do I need to become a driver?",
    "Driver onboarding is planned through the mobile app, including identity, driving licence and vehicle document review. Final eligibility and local requirements will be confirmed before live registration opens.",
  ],
  [
    "Which payment methods are supported?",
    `${projectConfig.defaultCurrency} is the initial display currency. Cash, EcoCash, OneMoney, bank cards and bank transfers are being considered; none is confirmed as operational. Availability will depend on verified provider integrations in the mobile app. This website does not process payments.`,
  ],
  [
    "How does Trivia approach safety?",
    "The planned approach includes driver review, clear driver and vehicle details, trip visibility and accessible reporting. These features are still being developed and are not operational safety or emergency services on this website.",
  ],
];
