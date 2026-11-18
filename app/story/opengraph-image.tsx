// The liner notes set their own `openGraph` (title, description, type: article), and a page's
// `openGraph` replaces the one it would inherit, image included, so a shared link to this page had no
// picture. Re-exporting the root card puts it back, the way `twitter-image.tsx` reuses it.
export { default, alt, size, contentType } from '../opengraph-image'
