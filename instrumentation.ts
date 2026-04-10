import * as Sentry from "@sentry/nextjs";
import { createTransport } from "@sentry/core";

function detectEnvironment(): string {
  // The preview-deploy.yml workflow sets PR_NUMBER on tagged revisions.
  // Production revisions don't have PR_NUMBER set.
  if (process.env.PR_NUMBER) return "preview";
  if (process.env.NODE_ENV === "production") return "production";
  return process.env.NODE_ENV || "development";
}

export function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    const dsn = process.env.SENTRY_DSN;
    const environment = detectEnvironment();

    if (dsn) {
      // External Sentry/GlitchTip — use the DSN directly
      Sentry.init({ dsn, environment, tracesSampleRate: 0 });
    } else {
      // Zero-config: route error events to our own /api/error-events
      // endpoint using a custom transport. The tunnel option only works
      // client-side; server-side requires an absolute URL transport.
      //
      // Cloud Run does not expose the service URL as an env var, so the
      // app needs to provide NEXT_PUBLIC_APP_URL or APP_URL at deploy time.
      // NEXT_PUBLIC_APP_URL is baked in at build time via --build-arg in
      // the Dockerfile; APP_URL can be set at runtime via
      // `gcloud run services update --set-env-vars`.
      const baseUrl =
        process.env.NEXT_PUBLIC_APP_URL || process.env.APP_URL || "";
      if (baseUrl) {
        const host = baseUrl.replace(/^https?:\/\//, "");
        const endpoint = `${baseUrl}/api/error-events`;
        Sentry.init({
          dsn: `https://self@${host}/0`,
          environment,
          tracesSampleRate: 0,
          transport: (options: Parameters<typeof createTransport>[0]) =>
            createTransport(options, async (request) => {
              try {
                const res = await fetch(endpoint, {
                  method: "POST",
                  body: request.body as string,
                });
                return { statusCode: res.status };
              } catch (e) {
                console.error("Self-transport failed:", e);
                return { statusCode: 500 };
              }
            }),
        });
      }
    }
  }
}

// Next.js 15+ hook: captures unhandled errors from API routes,
// Server Components, and Server Actions.
export const onRequestError = Sentry.captureRequestError;
