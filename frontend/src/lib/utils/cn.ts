/**
 * Combine class names. Expand with tailwind-merge in Phase 4.
 */
export function cn(...classes: (string | undefined)[]): string {
  return classes.filter(Boolean).join(" ");
}
