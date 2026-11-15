// Desktop and mobile share the same route labels and ordering.
export const primaryNavigation = [
  ["/", "Home"],
  ["/how-it-works", "How It Works"],
  ["/ride", "Ride With Trivia"],
  ["/drive", "Drive With Trivia"],
  ["/safety", "Safety"],
  ["/about", "About Us"],
] as const;
export const secondaryNavigation = [
  ["/contact", "Contact & Support"],
  ["/faq", "FAQs"],
  ["/#why-trivia", "Why Trivia"],
] as const;
// Matches Navbar.css; below this width the full link set cannot fit comfortably.
export const desktopNavigationQuery = "(min-width: 1240px)";
