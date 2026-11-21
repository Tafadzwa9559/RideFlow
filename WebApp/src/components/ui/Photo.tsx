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
  passenger: [1200, 900],
  "passenger-car": [1200, 900],
  driver: [1200, 900],
  "driver-portrait": [1200, 900],
  "city-driver": [1200, 751],
  navigation: [1200, 1200],
  safety: [1200, 1200],
  harare: [1200, 675],
  suv: [1200, 900],
  interior: [1200, 900],
  "car-journey": [1200, 675],
} as const;
const descriptions = {
  "city-car": "A Trivia-branded car on Jacaranda Avenue in Harare",
  passenger:
    "A woman smiling at the driver as she opens the door of a silver car under jacaranda trees",
  "passenger-car":
    "A passenger's hands holding a phone in the back seat of a car in central Harare",
  driver:
    "A smiling driver at the wheel of a white Toyota Aqua on a city street",
  "driver-portrait":
    "A smiling driver leaning on his silver Honda Fit on a tree-lined street",
  "city-driver":
    "A white Toyota Aqua driving along a busy Harare street lined with jacaranda trees",
  navigation:
    "A young man checking a route on his phone on a busy Harare pavement",
  safety:
    "A passenger checking her phone in the back seat at night while the driver smiles",
  harare: "A Trivia-branded car in downtown Harare",
  suv: "Two colleagues looking at a laptop together in a bright office with a view of the city",
  interior:
    "The inside of a Toyota Aqua with a phone mounted on the dashboard, looking down a Harare street",
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
