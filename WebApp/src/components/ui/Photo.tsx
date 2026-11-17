import { useRef, type ReactNode } from "react";
import {
  motion,
  useReducedMotion,
  useScroll,
  useTransform,
} from "motion/react";
import ScrollReveal, { type RevealDirection } from "../common/ScrollReveal";
const dimensions = {
  "city-car": [1200, 675],
  passenger: [1024, 768],
  "passenger-car": [1024, 768],
  driver: [1152, 768],
  "driver-portrait": [1152, 768],
  "city-driver": [1200, 675],
  navigation: [1200, 675],
  safety: [1152, 768],
  harare: [1200, 675],
  suv: [1200, 675],
  interior: [1152, 768],
  "car-journey": [1200, 675],
} as const;
const descriptions = {
  "city-car": "A Trivia-branded car on Jacaranda Avenue in Harare",
  passenger: "A woman requesting a ride on her phone on a city street",
  "passenger-car":
    "A passenger booking a Trivia ride beside a branded car in Harare",
  driver: "A smiling driver at the wheel on First Street in Harare",
  "driver-portrait": "A smiling driver beside a car at a city fountain",
  "city-driver": "A Trivia driver smiling from a car on a busy city street",
  navigation: "A driver checking navigation on a phone in downtown Harare",
  safety: "A smiling man standing beside a car on a busy Harare street",
  harare: "A Trivia-branded car in downtown Harare",
  suv: "A Trivia-branded car beneath blooming jacaranda trees",
  interior: "A woman driving through Bulawayo",
  "car-journey": "A Trivia-branded car driving through Harare at golden hour",
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
