import type { NextConfig } from "next";
import { withSentryConfig } from "@sentry/nextjs";

// Cloud Run target: use standalone output. This produces .next/standalone/
// with a self-contained server + pruned node_modules, which the Dockerfile
// copies into a minimal runtime image.
//
// If you deploy this template to Render or any other platform, verify that
// static file serving works with standalone before shipping — some platforms
// mishandle the static asset copy step.
const nextConfig: NextConfig = {
  output: "standalone",
};

export default withSentryConfig(nextConfig, {
  // Disable source map uploads — no auth token in zero-config mode
  sourcemaps: { disable: true },
  // Disable telemetry to Sentry's servers
  telemetry: false,
  // Suppress build logs about missing SENTRY_AUTH_TOKEN
  silent: true,
});
