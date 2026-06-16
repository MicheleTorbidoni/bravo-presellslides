// Shared 16:9 letterbox "stage" for every prospect-facing surface (hub, slide
// flow, closing page). Black bars fill the viewport; the stage stays a fixed 16:9
// in the middle so all three surfaces read as the same presentation. Each surface
// passes its own background via `className` (hub grey / slide green / closing
// slate). Carries the Bravo `font-bm` (Outfit). Autonomous UI — no template
// design system, raw Tailwind only.
import type { ReactNode } from "react"

export function Stage({
  children,
  onClick,
  className,
}: {
  children: ReactNode
  onClick?: () => void
  className?: string
}) {
  return (
    <div
      onClick={onClick}
      className={[
        "flex min-h-screen w-full items-center justify-center bg-black font-bm",
        onClick ? "cursor-pointer" : "",
      ].join(" ")}
    >
      <div
        className={[
          "relative aspect-[16/9] max-h-screen w-full max-w-[177.78vh] overflow-hidden [container-type:inline-size]",
          className ?? "",
        ].join(" ")}
      >
        {children}
      </div>
    </div>
  )
}
