// bm-design-system: accordion primitive
import * as React from "react";
import { ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils";

// Built on the native <details>/<summary> elements: no JS state, keyboard- and
// screen-reader-accessible for free, and SSR-safe. Collapsed by default; pass the
// standard `open` attribute to render it expanded. Each <Accordion> is a single
// independent collapsible item — stack several (with spacing) for a group.
const Accordion = React.forwardRef<
  HTMLDetailsElement,
  React.ComponentPropsWithoutRef<"details">
>(({ className, ...props }, ref) => (
  <details ref={ref} className={cn("accordion", className)} {...props} />
));
Accordion.displayName = "Accordion";

const AccordionTrigger = React.forwardRef<
  HTMLElement,
  React.ComponentPropsWithoutRef<"summary"> & {
    // Optional supporting line shown under the title, inside the trigger.
    description?: React.ReactNode;
  }
>(({ className, children, description, ...props }, ref) => (
  <summary ref={ref} className={cn("accordion-trigger", className)} {...props}>
    <span className="min-w-0">
      <span className="accordion-title">{children}</span>
      {description && <span className="accordion-description">{description}</span>}
    </span>
    <ChevronDown className="accordion-chevron" aria-hidden="true" />
  </summary>
));
AccordionTrigger.displayName = "AccordionTrigger";

const AccordionContent = React.forwardRef<
  HTMLDivElement,
  React.ComponentPropsWithoutRef<"div">
>(({ className, ...props }, ref) => (
  <div ref={ref} className={cn("accordion-content", className)} {...props} />
));
AccordionContent.displayName = "AccordionContent";

export { Accordion, AccordionTrigger, AccordionContent };
