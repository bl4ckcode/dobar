# Frontend System Design

## Rendering & Delivery Models
- **SSG (Static Site Generation):** Fast, high SEO, pre-built at deploy time.
- **ISR (Incremental Static Regeneration):** Background rebuilds parts of the site when content changes.
- **SSR (Server-Side Rendering):** Server builds pages per request. Great for live, personalized data.
- **CSR (Client-Side Rendering):** Browser loads JavaScript and builds UI. High interactivity (e.g., Figma), but slower initial load.
- **Hybrid Rendering:** Mixes these based on route needs (e.g., SSG for homepage, SSR for user profile, CSR for cart).
- **Edge Delivery / CDNs:** Serves static content from nearby nodes to reduce TTFB.

## Performance & UX Optimization
- **Metrics:** TTFB (Time to First Byte), FCP (First Contentful Paint), LCP (Largest Contentful Paint), CLS (Cumulative Layout Shift).
- **Lazy Loading & Caching:** Load heavy assets only when visible. Use Service Workers to cache resources (PWA / Offline-First).
- **Security:** XSS (Cross-Site Scripting), CSRF (Cross-Site Request Forgery), CSP (Content Security Policy) are critical. 

## Correlation with Dobar Ecosystem (Barz FE)
- **App-OpenFisio & Foodly_UI References:** Our Flutter / JS web clients should focus on optimizing LCP and TTFB to ensure that venue scanning flows load instantly.
- **State Management:** Enforce clear boundaries between local state (e.g., an expandable item) and global state (e.g., user auth, cart contents).
- **Observability:** Introduce frontend error tracking (like Sentry) to catch JS exceptions and layout shifts transparently across both Latin and North American users.
