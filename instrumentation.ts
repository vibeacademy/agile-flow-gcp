import * as Sentry from "@sentry/nextjs";

export function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    const dsn = process.env.SENTRY_DSN;

    if (dsn) {
      // External Sentry/GlitchTip — use the DSN directly
      Sentry.init({ dsn, tracesSampleRate: 0 });
    } else {
      // Zero-config: tunnel events to our own error-events endpoint.
      // A dummy DSN is required for the SDK to initialize; the tunnel
      // option overrides where envelopes are actually sent.
      Sentry.init({
        dsn: "https://self@localhost/0",
        tunnel: "/api/error-events",
        tracesSampleRate: 0,
      });
    }
  }
}
