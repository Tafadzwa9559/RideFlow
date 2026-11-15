import ScrollReveal from "../common/ScrollReveal";
import { useId, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
export default function FAQAccordion({
  items,
}: {
  items: readonly (readonly [string, string])[];
}) {
  const [open, setOpen] = useState<number | null>(null);
  const id = useId();
  const reduced = useReducedMotion();
  return (
    <div className="site-faq-list">
      {items.map(([question, answer], index) => {
        const expanded = open === index;
        const panelId = `${id}-${index}`;
        const buttonId = `${panelId}-trigger`;
        return (
          <ScrollReveal
            as="div"
            delay={(index % 3) * 0.06}
            distance={24}
            className="faq-item"
            key={question}
          >
            <h3>
              <button
                id={buttonId}
                type="button"
                aria-expanded={expanded}
                aria-controls={panelId}
                onClick={() => setOpen(expanded ? null : index)}
              >
                {question}
                <motion.span
                  aria-hidden="true"
                  animate={{ rotate: expanded ? 45 : 0 }}
                  transition={{ duration: reduced ? 0 : 0.2 }}
                >
                  +
                </motion.span>
              </button>
            </h3>
            <div id={panelId} aria-hidden={!expanded} inert={!expanded}>
            <AnimatePresence initial={false}>
              {expanded && (
                <motion.div
                  role="region"
                  aria-labelledby={buttonId}
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: "auto", opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  transition={{
                    duration: reduced ? 0 : 0.24,
                    ease: [0.22, 1, 0.36, 1],
                  }}
                  style={{ overflow: "hidden" }}
                >
                  <p>{answer}</p>
                </motion.div>
              )}
            </AnimatePresence>
            </div>
          </ScrollReveal>
        );
      })}
    </div>
  );
}
