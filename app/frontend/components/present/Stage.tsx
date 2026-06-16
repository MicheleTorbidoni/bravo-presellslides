// Shared 16:9 letterbox "stage" for every prospect-facing surface (hub, slide
// flow, closing page). Black bars fill the viewport; the slate stage stays a
// fixed 16:9 in the middle so all three surfaces read as the same presentation.
// Autonomous UI — no template design system, raw Tailwind only.
import type { ReactNode } from "react"

export function Stage({
  children,
  onClick,
}: {
  children: ReactNode
  onClick?: () => void
}) {
  return (
    <div
      onClick={onClick}
      className={[
        "flex min-h-screen w-full items-center justify-center bg-black",
        onClick ? "cursor-pointer" : "",
      ].join(" ")}
    >
      <div className="relative aspect-[16/9] max-h-screen w-full max-w-[177.78vh] bg-slate-950 text-white">
        {children}
      </div>
    </div>
  )
}
