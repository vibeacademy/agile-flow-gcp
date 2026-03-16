import * as Sentry from "@sentry/nextjs";
import { createTransport } from "@sentry/core";

export function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    const dsn = process.env.SENTRY_DSN;

    if (dsn) {
      // External Sentry/GlitchTip — use the DSN directly
      Sentry.init({ dsn, tracesSampleRate: 0 });
    } else {
      // Zero-config: route error events to our own /api/error-events
      // endpoint using a custom transport. The tunnel option only works
      // client-side; server-side requires an absolute URL transport.
      const baseUrl =
        process.env.RENDER_EXTERNAL_URL || process.env.APP_URL || "";
      if (baseUrl) {
        const host = baseUrl.replace(/^https?:\/\//, "");
        const endpoint = `${baseUrl}/api/error-events`;
        Sentry.init({
          dsn: `https://self@${host}/0`,
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
