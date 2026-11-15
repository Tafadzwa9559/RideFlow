// History entry keys distinguish repeated visits to the same public route.
export const scrollPositions = new Map<string, number>();
export function rememberScroll(key: string) {
  scrollPositions.set(key, window.scrollY);
  if (scrollPositions.size > 80)
    scrollPositions.delete(scrollPositions.keys().next().value!);
}
