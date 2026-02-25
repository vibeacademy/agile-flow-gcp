import * as Sentry from "@sentry/nextjs";

export function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    let dsn = process.env.SENTRY_DSN;

    if (!dsn) {
      // Self-DSN: point Sentry back at our own error-events endpoint
      const baseUrl =
        process.env.RENDER_EXTERNAL_URL || process.env.APP_URL || "";
      if (baseUrl) {
        const host = baseUrl.replace(/^https?:\/\//, "");
        dsn = `https://self@${host}/api/error-events/0`;
      }
    }

    if (dsn) {
      Sentry.init({
        dsn,
        tracesSampleRate: 0,
      });
    }
  }
}
