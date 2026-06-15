// Lightweight helper for the session auto-save endpoint (PATCH /presale_sessions/:id),
// which is a plain fetch sink returning `head :ok` rather than an Inertia response.
// Using the Inertia router here would break (it expects an X-Inertia response), so we
// call fetch directly and attach the CSRF token from the <meta name="csrf-token"> tag.
//
// `document` is read at call time (inside the function), never at module top-level,
// so importing this file stays SSR-safe.

function csrfToken(): string {
  if (typeof document === "undefined") return ""
  return (
    document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute("content") ?? ""
  )
}

export async function apiPatch(
  url: string,
  data: Record<string, unknown>,
): Promise<Response> {
  const response = await fetch(url, {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": csrfToken(),
    },
    body: JSON.stringify(data),
    credentials: "same-origin",
  })

  if (!response.ok) {
    throw new Error(`Auto-save failed (${response.status})`)
  }

  return response
}
