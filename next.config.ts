import type { NextConfig } from "next";
import { withSentryConfig } from "@sentry/nextjs";

// WARNING: Do not add output: "standalone" — Render's static file copy step
// is unreliable and causes CSS/JS/font 404s. Use `npm start` (next start)
// which handles static file serving natively.
// See docs/PATTERN-LIBRARY.md #9 for details.
const nextConfig: NextConfig = {};

export default withSentryConfig(nextConfig, {
  // Disable source map uploads — no auth token in zero-config mode
  sourcemaps: { disable: true },
  // Disable telemetry to Sentry's servers
  telemetry: false,
  // Suppress build logs about missing SENTRY_AUTH_TOKEN
  silent: true,
});
