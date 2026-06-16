// Bravo Manufacturing wordmark for the prospect-facing surfaces (M5). Two colour
// variants exported from the Figma file: "color" (slate + green, for light
// backgrounds like the hub) and "white" (for the green slide / slate closing
// backgrounds). Autonomous UI — no template design system. SSR-safe: the imports
// resolve to plain asset URL strings.
import logoColor from "@/assets/prospect/bravo-logo-color.svg"
import logoWhite from "@/assets/prospect/bravo-logo-white.svg"

export function Logo({
  variant,
  className,
}: {
  variant: "color" | "white"
  className?: string
}) {
  return (
    <img
      src={variant === "white" ? logoWhite : logoColor}
      alt="Bravo Manufacturing"
      className={className}
    />
  )
}
