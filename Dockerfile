# syntax=docker/dockerfile:1.7
#
# Multi-stage Dockerfile for Next.js on Google Cloud Run.
#
# Build contract:
# - Next.js `output: 'standalone'` must be set in next.config.ts
# - NEXT_PUBLIC_* env vars must be passed as --build-arg (they are
#   inlined into the client bundle at build time, not read at runtime)
# - Final image runs as non-root on port 8080
#
# See docs/PLATFORM-GUIDE.md for the full Cloud Run deploy flow.

# --- deps: install production dependencies only ---
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# --- builder: build the Next.js app ---
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# NEXT_PUBLIC_* variables are baked into the client bundle here.
# Pass them via --build-arg when invoking `docker build`:
#   docker build --build-arg NEXT_PUBLIC_APP_URL=https://... .
ARG NEXT_PUBLIC_APP_URL
ENV NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL

ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# --- runner: minimal runtime image ---
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=8080
# HOSTNAME=0.0.0.0 is REQUIRED. Without it, the Next.js server binds to
# localhost and Cloud Run health checks fail silently with "container
# starting but not ready." See docs/PATTERN-LIBRARY.md.
ENV HOSTNAME=0.0.0.0

# Non-root user (hardening; Cloud Run does not require it)
RUN addgroup --system --gid 1001 nodejs \
 && adduser --system --uid 1001 nextjs

# Copy only the standalone server + static assets + public.
# Everything else is discarded, shrinking the image from ~1 GB to ~150 MB.
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs
EXPOSE 8080

# With output: 'standalone', the entry point is `node server.js`,
# NOT `next start`. `next` is not present in the standalone bundle.
CMD ["node", "server.js"]
