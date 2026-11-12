
import { useState } from "react";
import {
  ArrowRight,
  ArrowUpRight,
  MapPin,
  Navigation,
  Menu,
  X,
  CarFront,
  ShieldCheck,
  Clock3,
  Wallet,
  CheckCircle2,
  Star,
  Users,
  Route,
  ChevronDown,
  Smartphone,
  Headphones,
  LocateFixed,
  Minus,
  Plus,
  Search,
  Zap,
  CreditCard,
  BadgeCheck,
  CalendarDays,
  Check,
} from "lucide-react";

const rideTypes = [
  {
    id: "standard",
    name: "RideFlow Standard",
    subtitle: "Affordable everyday rides",
    icon: CarFront,
    rate: 1,
    capacity: 4,
    eta: "4 min",
  },
  {
    id: "comfort",
    name: "RideFlow Comfort",
    subtitle: "Extra comfort for your journey",
    icon: CarFront,
    rate: 1.5,
    capacity: 4,
    eta: "6 min",
  },
  {
    id: "xl",
    name: "RideFlow XL",
    subtitle: "Room for the whole group",
    icon: Users,
    rate: 1.9,
    capacity: 6,
    eta: "8 min",
  },
];

const features = [
  {
    icon: Wallet,
    title: "Fair, flexible fares",
    description:
      "See an estimated fare before requesting your ride. Know what to expect.",
  },
  {
    icon: ShieldCheck,
    title: "Safety first",
    description:
      "A platform designed around trusted drivers, trip visibility and safer journeys.",
  },
  {
    icon: Clock3,
    title: "Save your time",
    description:
      "A simple booking experience that gets you from planning to requesting a ride quickly.",
  },
  {
    icon: Navigation,
    title: "Your journey, your choice",
    description:
      "Choose the ride category that suits your budget, comfort and travel needs.",
  },
];

const steps = [
  {
    number: "01",
    title: "Set your destination",
    description:
      "Enter where you're leaving from and where you want to go.",
  },
  {
    number: "02",
    title: "Choose your ride",
    description:
      "Compare ride options and select the one that works for you.",
  },
  {
    number: "03",
    title: "Request your driver",
    description:
      "Confirm your request and get ready for your journey.",
  },
];

function Logo({ light = true }) {
  return (
    <a href="#home" className="flex items-center gap-3">
      <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-500">
        <Route size={23} strokeWidth={2.5} className="text-slate-950" />
      </div>
      <span
        className={`text-2xl font-extrabold tracking-tight ${
          light ? "text-white" : "text-slate-950"
        }`}
      >
        Ride<span className="text-emerald-400">Flow</span>
      </span>
    </a>
  );
}

function SectionHeader({ eyebrow, title, description, dark = true }) {
  return (
    <div className="mx-auto mb-14 max-w-2xl text-center">
      <div className="mb-4 inline-flex rounded-full border border-emerald-500/20 bg-emerald-500/10 px-4 py-2 text-xs font-bold uppercase tracking-[0.2em] text-emerald-500">
        {eyebrow}
      </div>
      <h2
        className={`text-3xl font-bold tracking-tight md:text-5xl ${
          dark ? "text-white" : "text-slate-950"
        }`}
      >
        {title}
      </h2>
      <p
        className={`mt-5 leading-8 ${
          dark ? "text-slate-400" : "text-slate-600"
        }`}
      >
        {description}
      </p>
    </div>
  );
}

function BookingForm() {
  const [pickup, setPickup] = useState("");
  const [destination, setDestination] = useState("");
  const [selectedRide, setSelectedRide] = useState("standard");
  const [passengers, setPassengers] = useState(1);
  const [payment, setPayment] = useState("cash");
  const [step, setStep] = useState(1);
  const [error, setError] = useState("");
  const [completed, setCompleted] = useState(false);

  const ride = rideTypes.find((item) => item.id === selectedRide);

  // Demo pricing only. Replace with a backend routing/fare API.
  const estimatedFare = (5.5 * ride.rate).toFixed(2);

  function continueBooking() {
    if (!pickup.trim() || !destination.trim()) {
      setError("Please enter your pickup and destination.");
      return;
    }

    if (pickup.trim().toLowerCase() === destination.trim().toLowerCase()) {
      setError("Pickup and destination must be different.");
      return;
    }

    setError("");
    setStep(2);
  }

  function confirmBooking() {
    setCompleted(true);
    setStep(3);
  }

  function resetBooking() {
    setPickup("");
    setDestination("");
    setSelectedRide("standard");
    setPassengers(1);
    setPayment("cash");
    setStep(1);
    setCompleted(false);
    setError("");
  }

  return (
    <div
      id="booking"
      className="w-full rounded-[28px] border border-white/10 bg-slate-900 p-5 shadow-2xl shadow-black/30 sm:p-7"
    >
      <div className="mb-7 flex items-start justify-between">
        <div>
          <div className="mb-2 inline-flex items-center gap-2 text-xs font-semibold uppercase tracking-widest text-emerald-400">
            <span className="h-2 w-2 rounded-full bg-emerald-400" />
            Ride booking
          </div>
          <h3 className="text-2xl font-bold text-white">
            {step === 1
              ? "Where to?"
              : step === 2
              ? "Review your ride"
              : "Request prepared"}
          </h3>
          <p className="mt-2 text-sm text-slate-400">
            {step === 1
              ? "Plan your next journey in a few simple steps."
              : step === 2
              ? "Confirm your trip details."
              : "Your demo request is ready."}
          </p>
        </div>
        <div className="rounded-xl bg-emerald-500/10 p-3 text-emerald-400">
          <Navigation size={22} />
        </div>
      </div>

      <div className="mb-7 flex items-center gap-2">
        {[1, 2, 3].map((item) => (
          <div
            key={item}
            className={`h-1.5 flex-1 rounded-full transition-all ${
              step >= item ? "bg-emerald-500" : "bg-slate-700"
            }`}
          />
        ))}
      </div>

      {step === 1 && (
        <div className="space-y-5">
          <div className="relative space-y-3">
            <div className="absolute bottom-14 left-[22px] top-14 w-px border-l border-dashed border-slate-600" />

            <div className="flex items-center gap-3 rounded-2xl border border-white/10 bg-slate-950 p-4 focus-within:border-emerald-500">
              <LocateFixed className="shrink-0 text-emerald-400" size={20} />
              <div className="min-w-0 flex-1">
                <label
                  htmlFor="pickup"
                  className="mb-1 block text-xs text-slate-500"
                >
                  Pickup location
                </label>
                <input
                  id="pickup"
                  type="text"
                  value={pickup}
                  onChange={(e) => setPickup(e.target.value)}
                  placeholder="Enter pickup location"
                  className="w-full bg-transparent text-sm text-white outline-none placeholder:text-slate-600"
                />
              </div>
            </div>

            <div className="flex items-center gap-3 rounded-2xl border border-white/10 bg-slate-950 p-4 focus-within:border-emerald-500">
              <MapPin className="shrink-0 text-orange-400" size={20} />
              <div className="min-w-0 flex-1">
                <label
                  htmlFor="destination"
                  className="mb-1 block text-xs text-slate-500"
                >
                  Destination
                </label>
                <input
                  id="destination"
                  type="text"
                  value={destination}
                  onChange={(e) => setDestination(e.target.value)}
                  placeholder="Where are you going?"
                  className="w-full bg-transparent text-sm text-white outline-none placeholder:text-slate-600"
                />
              </div>
            </div>
          </div>

          <div>
            <div className="mb-3 flex items-center justify-between">
              <label className="text-sm font-medium text-white">
                Choose your ride
              </label>
              <span className="text-xs text-slate-500">3 options</span>
            </div>

            <div className="space-y-2">
              {rideTypes.map((item) => {
                const Icon = item.icon;
                const active = selectedRide === item.id;

                return (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => setSelectedRide(item.id)}
                    className={`flex w-full items-center gap-3 rounded-2xl border p-3 text-left transition-all ${
                      active
                        ? "border-emerald-500 bg-emerald-500/10"
                        : "border-white/10 bg-slate-950 hover:border-slate-600"
                    }`}
                  >
                    <div
                      className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-xl ${
                        active
                          ? "bg-emerald-500 text-slate-950"
                          : "bg-slate-800 text-slate-300"
                      }`}
                    >
                      <Icon size={23} />
                    </div>

                    <div className="min-w-0 flex-1">
                      <div className="text-sm font-semibold text-white">
                        {item.name}
                      </div>
                      <div className="mt-1 text-xs text-slate-400">
                        {item.subtitle}
                      </div>
                      <div className="mt-1 text-xs text-slate-500">
                        Up to {item.capacity} seats
                      </div>
                    </div>

                    <div className="text-right">
                      <div className="font-bold text-white">
                        ${(5.5 * item.rate).toFixed(2)}
                      </div>
                      <div className="mt-1 text-xs text-slate-500">
                        Demo fare
                      </div>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="flex items-center justify-between rounded-2xl border border-white/10 bg-slate-950 p-4">
            <div>
              <p className="text-sm font-semibold text-white">Passengers</p>
              <p className="mt-1 text-xs text-slate-500">
                Number of people travelling
              </p>
            </div>

            <div className="flex items-center gap-4">
              <button
                type="button"
                aria-label="Remove passenger"
                onClick={() => setPassengers(Math.max(1, passengers - 1))}
                className="rounded-lg bg-slate-800 p-2 text-white hover:bg-slate-700"
              >
                <Minus size={16} />
              </button>
              <span className="font-semibold text-white">{passengers}</span>
              <button
                type="button"
                aria-label="Add passenger"
                onClick={() =>
                  setPassengers(
                    Math.min(ride.capacity, passengers + 1)
                  )
                }
                disabled={passengers >= ride.capacity}
                className="rounded-lg bg-slate-800 p-2 text-white hover:bg-slate-700 disabled:cursor-not-allowed disabled:opacity-30"
              >
                <Plus size={16} />
              </button>
            </div>
          </div>

          {error && (
            <p role="alert" className="text-sm text-red-400">
              {error}
            </p>
          )}

          <button
            type="button"
            onClick={continueBooking}
            className="flex w-full items-center justify-center gap-3 rounded-2xl bg-emerald-500 px-6 py-4 font-bold text-slate-950 transition hover:bg-emerald-400"
          >
            Continue
            <ArrowRight size={19} />
          </button>
        </div>
      )}

      {step === 2 && (
        <div className="space-y-5">
          <div className="space-y-4 rounded-2xl border border-white/10 bg-slate-950 p-5">
            <div className="flex gap-3">
              <LocateFixed size={19} className="shrink-0 text-emerald-400" />
              <div className="min-w-0">
                <p className="text-xs text-slate-500">Pickup</p>
                <p className="break-words text-sm font-semibold text-white">
                  {pickup}
                </p>
              </div>
            </div>
            <div className="h-px bg-slate-800" />
            <div className="flex gap-3">
              <MapPin size={19} className="shrink-0 text-orange-400" />
              <div className="min-w-0">
                <p className="text-xs text-slate-500">Destination</p>
                <p className="break-words text-sm font-semibold text-white">
                  {destination}
                </p>
              </div>
            </div>
          </div>

          <div className="rounded-2xl border border-white/10 bg-slate-950 p-5">
            <div className="flex justify-between text-sm">
              <span className="text-slate-400">Vehicle</span>
              <span className="font-semibold text-white">{ride.name}</span>
            </div>
            <div className="mt-4 flex justify-between text-sm">
              <span className="text-slate-400">Passengers</span>
              <span className="text-white">{passengers}</span>
            </div>
            <div className="mt-4 flex justify-between text-sm">
              <span className="text-slate-400">Illustrative arrival</span>
              <span className="text-white">{ride.eta}</span>
            </div>
            <div className="my-5 h-px bg-slate-800" />
            <div className="flex justify-between">
              <span className="font-semibold text-white">Demo fare</span>
              <span className="text-2xl font-bold text-emerald-400">
                ${estimatedFare}
              </span>
            </div>
            <p className="mt-3 text-xs leading-5 text-slate-500">
              Example price only. Actual fares require routing,
              distance, pricing and driver availability services.
            </p>
          </div>

          <div>
            <p className="mb-3 text-sm font-semibold text-white">
              Payment preference
            </p>
            <div className="grid grid-cols-2 gap-3">
              {[
                { id: "cash", label: "Cash", icon: Wallet },
                { id: "card", label: "Card", icon: CreditCard },
              ].map((item) => {
                const Icon = item.icon;
                return (
                  <button
                    type="button"
                    key={item.id}
                    onClick={() => setPayment(item.id)}
                    className={`flex items-center justify-center gap-2 rounded-xl border p-4 text-sm font-medium ${
                      payment === item.id
                        ? "border-emerald-500 bg-emerald-500/10 text-emerald-400"
                        : "border-white/10 text-slate-400"
                    }`}
                  >
                    <Icon size={18} />
                    {item.label}
                  </button>
                );
              })}
            </div>
          </div>

          <div className="flex gap-3">
            <button
              type="button"
              onClick={() => setStep(1)}
              className="rounded-xl border border-white/10 px-6 py-4 font-semibold text-white hover:bg-white/5"
            >
              Back
            </button>
            <button
              type="button"
              onClick={confirmBooking}
              className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-emerald-500 px-4 py-4 font-bold text-slate-950 hover:bg-emerald-400"
            >
              Confirm demo request
              <Check size={18} />
            </button>
          </div>
        </div>
      )}

      {step === 3 && completed && (
        <div className="py-8 text-center">
          <div className="mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-400">
            <CheckCircle2 size={44} />
          </div>
          <h4 className="text-2xl font-bold text-white">
            Your ride is ready to request!
          </h4>
          <p className="mx-auto mt-4 max-w-sm text-sm leading-7 text-slate-400">
            Your trip from {pickup} to {destination} has
            been prepared in this frontend demo. No driver has
            been contacted and no payment has been made.
          </p>

          <button
            type="button"
            onClick={resetBooking}
            className="mt-8 rounded-xl bg-emerald-500 px-8 py-3 font-bold text-slate-950 hover:bg-emerald-400"
          >
            Plan another ride
          </button>
        </div>
      )}
    </div>
  );
}

export default function App() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [faqOpen, setFaqOpen] = useState(null);

  const faqs = [
    {
      question: "What is RideFlow?",
      answer:
        "RideFlow is a ride-hailing platform concept designed to connect passengers and drivers through a simple digital booking experience.",
    },
    {
      question: "Can I choose a different vehicle?",
      answer:
        "Yes. The booking interface includes Standard, Comfort and XL options. Availability will depend on nearby registered drivers once the live backend is connected.",
    },
    {
      question: "How are fares calculated?",
      answer:
        "In this prototype, prices are illustrative. The live platform will calculate estimates using route distance, travel time, vehicle type and applicable pricing rules.",
    },
    {
      question: "Can I pay with cash?",
      answer:
        "The prototype supports cash and card as selectable preferences. Actual payments will require backend payment integrations.",
    },
  ];

  const closeMenu = () => setMobileMenuOpen(false);

  return (
    <div className="min-h-screen overflow-x-hidden bg-slate-950 font-sans text-white selection:bg-emerald-500 selection:text-slate-950">
      {/* Navigation */}
      <header className="sticky top-0 z-50 border-b border-white/10 bg-slate-950/95 backdrop-blur-xl">
        <nav className="mx-auto flex h-20 max-w-7xl items-center justify-between px-5 lg:px-8">
          <Logo />

          <div className="hidden items-center gap-9 lg:flex">
            {[
              ["Home", "#home"],
              ["How it works", "#how-it-works"],
              ["Our rides", "#rides"],
              ["Why RideFlow", "#features"],
              ["FAQ", "#faq"],
            ].map(([label, href]) => (
              <a
                key={label}
                href={href}
                className="text-sm font-medium text-slate-300 transition hover:text-emerald-400"
              >
                {label}
              </a>
            ))}
          </div>

          <div className="hidden items-center gap-3 lg:flex">
            <a
              href="#booking"
              className="rounded-xl px-5 py-3 text-sm font-semibold text-white hover:text-emerald-400"
            >
              Book a ride
            </a>
            <a
              href="#drivers"
              className="flex items-center gap-2 rounded-xl bg-emerald-500 px-5 py-3 text-sm font-bold text-slate-950 hover:bg-emerald-400"
            >
              Drive with us
              <ArrowUpRight size={17} />
            </a>
          </div>

          <button
            type="button"
            aria-label={mobileMenuOpen ? "Close menu" : "Open menu"}
            aria-expanded={mobileMenuOpen}
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="rounded-xl border border-white/10 p-3 lg:hidden"
          >
            {mobileMenuOpen ? <X size={22} /> : <Menu size={22} />}
          </button>
        </nav>

        {mobileMenuOpen && (
          <div className="border-t border-white/10 bg-slate-900 px-5 py-5 lg:hidden">
            <div className="flex flex-col gap-5">
              {[
                ["Home", "#home"],
                ["How it works", "#how-it-works"],
                ["Our rides", "#rides"],
                ["Why RideFlow", "#features"],
                ["FAQ", "#faq"],
              ].map(([label, href]) => (
                <a
                  key={label}
                  href={href}
                  onClick={closeMenu}
                  className="text-sm font-medium text-slate-300"
                >
                  {label}
                </a>
              ))}
              <a
                href="#booking"
                onClick={closeMenu}
                className="rounded-xl bg-emerald-500 px-5 py-3 text-center font-bold text-slate-950"
              >
                Book a ride
              </a>
            </div>
          </div>
        )}
      </header>

      {/* Hero */}
      <main>
        <section
          id="home"
          className="relative overflow-hidden border-b border-white/5"
        >
          <div className="pointer-events-none absolute right-0 top-0 h-[500px] w-[500px] rounded-full bg-emerald-500/10 blur-[150px]" />
          <div className="pointer-events-none absolute bottom-0 left-0 h-80 w-80 rounded-full bg-emerald-800/10 blur-[120px]" />

          <div className="relative mx-auto grid max-w-7xl items-center gap-14 px-5 py-16 lg:grid-cols-[1fr_440px] lg:gap-16 lg:px-8 lg:py-24">
            <div>
              <div className="mb-8 inline-flex items-center gap-2 rounded-full border border-emerald-500/20 bg-emerald-500/10 px-4 py-2 text-xs font-semibold tracking-wide text-emerald-400 sm:text-sm">
                <Zap size={15} />
                A smarter way to move
                <ArrowRight size={15} />
              </div>

              <h1 className="max-w-2xl text-5xl font-extrabold leading-[1.1] tracking-tight sm:text-6xl xl:text-7xl">
                Your city.
                <br />
                Your ride.
                <br />
                <span className="text-emerald-400">Your choice.</span>
              </h1>

              <p className="mt-7 max-w-lg text-base leading-8 text-slate-400 md:text-lg">
                Moving around should be simple. Discover a smarter,
                more comfortable way to get where you need to go
                with RideFlow.
              </p>

              <div className="mt-9 flex flex-wrap items-center gap-4">
                <a
                  href="#booking"
                  className="flex items-center gap-3 rounded-xl bg-emerald-500 px-7 py-4 font-bold text-slate-950 shadow-xl shadow-emerald-500/10 transition hover:-translate-y-0.5 hover:bg-emerald-400"
                >
                  Book your ride
                  <ArrowRight size={19} />
                </a>
                <a
                  href="#how-it-works"
                  className="flex items-center gap-3 rounded-xl border border-white/15 px-7 py-4 font-semibold text-white hover:bg-white/5"
                >
                  How it works
                  <ArrowUpRight size={18} />
                </a>
              </div>

              <div className="mt-12 grid max-w-md grid-cols-3 divide-x divide-white/10 border-t border-white/10 pt-8">
                <div className="pr-4">
                  <ShieldCheck className="mb-3 text-emerald-400" size={23} />
                  <p className="text-sm font-semibold">Safety focused</p>
                </div>
                <div className="px-4">
                  <Wallet className="mb-3 text-emerald-400" size={23} />
                  <p className="text-sm font-semibold">Fair pricing</p>
                </div>
                <div className="pl-4">
                  <Clock3 className="mb-3 text-emerald-400" size={23} />
                  <p className="text-sm font-semibold">Simple booking</p>
                </div>
              </div>
            </div>

            <BookingForm />
          </div>
        </section>

        {/* Introduction strip */}
        <section className="border-b border-white/10 bg-slate-900/50">
          <div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-5 px-5 py-8 text-center md:flex-row md:text-left lg:px-8">
            <div className="flex items-center gap-4">
              <div className="rounded-xl bg-emerald-500/10 p-3 text-emerald-400">
                <MapPin size={24} />
              </div>
              <div>
                <h3 className="font-bold text-white">
                  Built for the way you move
                </h3>
                <p className="mt-1 text-sm text-slate-400">
                  A new ride-hailing experience designed with local journeys in mind.
                </p>
              </div>
            </div>
            <a
              href="#features"
              className="flex shrink-0 items-center gap-2 text-sm font-bold text-emerald-400 hover:text-emerald-300"
            >
              Explore the platform
              <ArrowRight size={17} />
            </a>
          </div>
        </section>

        {/* How it works */}
        <section
          id="how-it-works"
          className="scroll-mt-24 px-5 py-24 lg:px-8"
        >
          <div className="mx-auto max-w-7xl">
            <SectionHeader
              eyebrow="Simple by design"
              title="Your next ride in three steps."
              description="No unnecessary complications. Just a straightforward experience designed to help you plan your journey."
            />

            <div className="grid gap-5 md:grid-cols-3">
              {steps.map((item) => (
                <div
                  key={item.number}
                  className="group rounded-3xl border border-white/10 bg-slate-900/70 p-8 transition hover:-translate-y-1 hover:border-emerald-500/40"
                >
                  <div className="mb-12 flex items-center justify-between">
                    <span className="text-5xl font-extrabold text-slate-700 transition group-hover:text-emerald-500">
                      {item.number}
                    </span>
                    <ArrowUpRight
                      size={22}
                      className="text-slate-500 transition group-hover:text-emerald-400"
                    />
                  </div>
                  <h3 className="text-xl font-bold text-white">
                    {item.title}
                  </h3>
                  <p className="mt-4 text-sm leading-7 text-slate-400">
                    {item.description}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* Ride categories */}
        <section
          id="rides"
          className="scroll-mt-24 bg-slate-900 px-5 py-24 lg:px-8"
        >
          <div className="mx-auto max-w-7xl">
            <SectionHeader
              eyebrow="Ride your way"
              title="A ride for every occasion."
              description="Whether you're heading to work, meeting friends or travelling as a group, choose the experience that fits."
            />

            <div className="grid gap-6 md:grid-cols-3">
              {rideTypes.map((item, index) => {
                const Icon = item.icon;
                return (
                  <div
                    key={item.id}
                    className={`relative flex flex-col overflow-hidden rounded-3xl border p-7 transition hover:-translate-y-1 ${
                      index === 1
                        ? "border-emerald-500/50 bg-slate-800"
                        : "border-white/10 bg-slate-950"
                    }`}
                  >
                    {index === 1 && (
                      <span className="absolute right-5 top-5 rounded-full bg-emerald-500 px-3 py-1 text-xs font-bold text-slate-950">
                        Extra comfort
                      </span>
                    )}

                    <div className="mb-8 flex h-20 w-20 items-center justify-center rounded-3xl bg-emerald-500/10 text-emerald-400">
                      <Icon size={38} strokeWidth={1.5} />
                    </div>

                    <h3 className="text-2xl font-bold text-white">
                      {item.name}
                    </h3>
                    <p className="mt-3 text-sm leading-7 text-slate-400">
                      {item.subtitle}
                    </p>

                    <div className="mt-7 flex items-center gap-5 border-t border-white/10 pt-6 text-sm text-slate-400">
                      <span className="flex items-center gap-2">
                        <Users size={17} className="text-emerald-400" />
                        {item.capacity} seats
                      </span>
                      <span className="flex items-center gap-2">
                        <BadgeCheck size={17} className="text-emerald-400" />
                        Flexible
                      </span>
                    </div>

                    <a
                      href="#booking"
                      className="mt-8 flex items-center justify-center gap-2 rounded-xl border border-emerald-500/30 px-5 py-3 font-bold text-emerald-400 transition hover:bg-emerald-500 hover:text-slate-950"
                    >
                      Choose this ride
                      <ArrowRight size={17} />
                    </a>
                  </div>
                );
              })}
            </div>
          </div>
        </section>

        {/* Features */}
        <section
          id="features"
          className="scroll-mt-24 px-5 py-24 lg:px-8"
        >
          <div className="mx-auto max-w-7xl">
            <div className="grid items-center gap-16 lg:grid-cols-2">
              <div>
                <div className="mb-5 inline-flex rounded-full bg-emerald-500/10 px-4 py-2 text-xs font-bold uppercase tracking-widest text-emerald-400">
                  Why RideFlow
                </div>
                <h2 className="max-w-lg text-4xl font-bold leading-tight tracking-tight md:text-5xl">
                  More than a ride.
                  <br />
                  <span className="text-emerald-400">
                    A better experience.
                  </span>
                </h2>
                <p className="mt-6 max-w-lg leading-8 text-slate-400">
                  RideFlow is designed around what matters most:
                  simplicity, flexibility, convenience and confidence
                  throughout your journey.
                </p>

                <a
                  href="#booking"
                  className="mt-8 inline-flex items-center gap-2 font-bold text-emerald-400"
                >
                  Explore ride booking
                  <ArrowRight size={18} />
                </a>
              </div>

              <div className="grid gap-4 sm:grid-cols-2">
                {features.map((feature) => {
                  const Icon = feature.icon;
                  return (
                    <div
                      key={feature.title}
                      className="rounded-2xl border border-white/10 bg-slate-900 p-6 transition hover:border-emerald-500/30"
                    >
                      <div className="mb-6 flex h-12 w-12 items-center justify-center rounded-xl bg-emerald-500/10 text-emerald-400">
                        <Icon size={23} />
                      </div>
                      <h3 className="text-lg font-bold">
                        {feature.title}
                      </h3>
                      <p className="mt-3 text-sm leading-7 text-slate-400">
                        {feature.description}
                      </p>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </section>

        {/* Driver CTA */}
        <section
          id="drivers"
          className="scroll-mt-24 px-5 pb-24 lg:px-8"
        >
          <div className="relative mx-auto max-w-7xl overflow-hidden rounded-[32px] bg-emerald-500 px-7 py-12 text-slate-950 md:px-14 md:py-16">
            <div className="pointer-events-none absolute -right-20 -top-20 h-80 w-80 rounded-full border-[45px] border-slate-950/5" />

            <div className="relative grid items-center gap-8 md:grid-cols-[1fr_auto]">
              <div>
                <div className="mb-5 inline-flex items-center gap-2 rounded-full bg-slate-950/10 px-4 py-2 text-xs font-bold uppercase tracking-wider">
                  <CarFront size={16} />
                  For drivers
                </div>
                <h2 className="max-w-xl text-3xl font-extrabold tracking-tight md:text-5xl">
                  Your car. Your time.
                  <br />
                  More possibilities.
                </h2>
                <p className="mt-5 max-w-xl leading-7 text-slate-900/80">
                  Interested in driving with RideFlow? Discover
                  the opportunity to join our future driver network.
                </p>
              </div>

              <a
                href="mailto:drivers@rideflow.example?subject=RideFlow%20Driver%20Interest"
                className="inline-flex items-center justify-center gap-3 rounded-xl bg-slate-950 px-7 py-4 font-bold text-white transition hover:bg-slate-800"
                onClick={(e) => {
                  e.preventDefault();
                  document.getElementById("faq")?.scrollIntoView({
                    behavior: "smooth",
                  });
                }}
              >
                Learn more
                <ArrowUpRight size={18} />
              </a>
            </div>
          </div>
        </section>

        {/* FAQ */}
        <section
          id="faq"
          className="scroll-mt-24 bg-slate-900 px-5 py-24 lg:px-8"
        >
          <div className="mx-auto max-w-3xl">
            <SectionHeader
              eyebrow="Need to know"
              title="Frequently asked questions."
              description="A few useful answers about the RideFlow experience."
            />

            <div className="space-y-3">
              {faqs.map((item, index) => (
                <div
                  key={item.question}
                  className="overflow-hidden rounded-2xl border border-white/10 bg-slate-950"
                >
                  <button
                    type="button"
                    aria-expanded={faqOpen === index}
                    onClick={() =>
                      setFaqOpen(faqOpen === index ? null : index)
                    }
                    className="flex w-full items-center justify-between gap-5 p-6 text-left font-semibold text-white"
                  >
                    {item.question}
                    <ChevronDown
                      size={20}
                      className={`shrink-0 text-emerald-400 transition-transform ${
                        faqOpen === index ? "rotate-180" : ""
                      }`}
                    />
                  </button>
                  {faqOpen === index && (
                    <p className="px-6 pb-6 text-sm leading-7 text-slate-400">
                      {item.answer}
                    </p>
                  )}
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* Final CTA */}
        <section className="px-5 py-24 text-center lg:px-8">
          <div className="mx-auto max-w-3xl">
            <div className="mx-auto mb-7 flex h-16 w-16 items-center justify-center rounded-2xl bg-emerald-500/10 text-emerald-400">
              <Navigation size={30} />
            </div>
            <h2 className="text-4xl font-extrabold tracking-tight md:text-5xl">
              Ready to go somewhere?
            </h2>
            <p className="mx-auto mt-6 max-w-xl leading-8 text-slate-400">
              Wherever the day takes you, RideFlow is designed
              to make planning your next journey feel effortless.
            </p>

            <a
              href="#booking"
              className="mt-8 inline-flex items-center gap-3 rounded-xl bg-emerald-500 px-8 py-4 font-bold text-slate-950 hover:bg-emerald-400"
            >
              Plan your ride
              <ArrowRight size={19} />
            </a>
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer className="border-t border-white/10 bg-slate-900 px-5 pt-16 lg:px-8">
        <div className="mx-auto grid max-w-7xl gap-12 pb-14 md:grid-cols-2 lg:grid-cols-4">
          <div className="lg:col-span-2">
            <Logo />
            <p className="mt-6 max-w-sm text-sm leading-7 text-slate-400">
              Your journey. Your choice. RideFlow is building a
              more convenient and flexible ride-hailing experience
              for everyday travel.
            </p>
          </div>

          <div>
            <h4 className="mb-6 font-bold text-white">Explore</h4>
            <div className="flex flex-col gap-4 text-sm text-slate-400">
              <a href="#home" className="hover:text-emerald-400">Home</a>
              <a href="#rides" className="hover:text-emerald-400">Our rides</a>
              <a href="#how-it-works" className="hover:text-emerald-400">How it works</a>
              <a href="#features" className="hover:text-emerald-400">Why RideFlow</a>
            </div>
          </div>

          <div>
            <h4 className="mb-6 font-bold text-white">Get started</h4>
            <div className="flex flex-col gap-4 text-sm text-slate-400">
              <a href="#booking" className="hover:text-emerald-400">Book a ride</a>
              <a href="#drivers" className="hover:text-emerald-400">Drive with us</a>
              <a href="#faq" className="hover:text-emerald-400">FAQs</a>
            </div>
          </div>
        </div>

        <div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-4 border-t border-white/10 py-7 text-center text-xs text-slate-500 md:flex-row">
          <p>© {new Date().getFullYear()} RideFlow. All rights reserved.</p>
          <p>Made for better journeys.</p>
        </div>
      </footer>
    </div>
  );
}
