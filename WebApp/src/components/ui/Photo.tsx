import { useRef, type ReactNode } from "react";
import {
  motion,
  useReducedMotion,
  useScroll,
  useTransform,
} from "motion/react";
import ScrollReveal, { type RevealDirection } from "../common/ScrollReveal";
const dimensions = {
  "city-car": [1200, 799],
  passenger: [1200, 800],
  driver: [1200, 800],
  navigation: [1200, 800],
  safety: [1200, 1801],
  harare: [1200, 1800],
  suv: [1200, 1734],
  interior: [1200, 1200],
} as const;
const descriptions = {
  "city-car":
    "A modern white car parked on a city street beside urban buildings",
  passenger: "A woman opening the passenger door of a taxi on a city street",
  driver: "A woman seated at the steering wheel of a car",
  navigation: "Hands checking a navigation map on a smartphone inside a car",
  safety: "A man seated inside a vehicle wearing a seat belt",
  harare: "Cars and buildings on a city-centre street in Harare, Zimbabwe",
  suv: "An SUV travelling along a coastal road in South Africa",
  interior: "A driver seated in a clean, modern vehicle interior",
} as const;
export type PhotoName = keyof typeof descriptions;
export default function Photo({
  name,
  className = "",
  eager = false,
  alt,
  wide = false,
  direction = "right",
  parallax = false,
  reveal = true,
}: {
  name: PhotoName;
  className?: string;
  eager?: boolean;
  alt?: string;
  wide?: boolean;
  direction?: RevealDirection;
  parallax?: boolean;
  reveal?: boolean;
}) {
  const reduced = useReducedMotion();
  const media = (
    <img
      src={`/photos/${name}-1200.webp`}
      srcSet={`/photos/${name}-640.webp 640w, /photos/${name}-1200.webp 1200w`}
      sizes={
        wide
          ? "(max-width: 1440px) 88vw, 1240px"
          : "(max-width: 760px) 90vw, (max-width: 1280px) 45vw, 600px"
      }
      alt={alt || descriptions[name]}
      width={dimensions[name][0]}
      height={dimensions[name][1]}
      loading={eager ? "eager" : "lazy"}
      fetchPriority={eager ? "high" : "auto"}
      decoding="async"
    />
  );
  const classes = `editorial-photo photo-${name} ${className}`;
  return reveal ? (
    <ScrollReveal as="figure" className={classes} direction={direction}>
      {parallax && !reduced ? <ParallaxFrame>{media}</ParallaxFrame> : media}
    </ScrollReveal>
  ) : (
    <figure className={classes}>{media}</figure>
  );
}

/** Only selected imagery subscribes to Motion's shared scroll measurements. */
function ParallaxFrame({ children }: { children: ReactNode }) {
  const target = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target,
    offset: ["start end", "end start"],
  });
  const y = useTransform(scrollYProgress, [0, 1], [8, -8]);
  return (
    <div ref={target} className="photo-reveal-frame" data-parallax>
      <motion.div className="parallax-media" style={{ y, scale: 1.08 }}>
        {children}
      </motion.div>
    </div>
  );
}
