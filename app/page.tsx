export default function Home() {
  return (
    <main>
      <h1>Agile Flow Starter</h1>
      <p>Your agentic development workflow is ready.</p>

      <h2>Endpoints</h2>
      <ul>
        <li>
          <code>GET /api/health</code> — Health check
        </li>
        <li>
          <code>GET /api/error</code> — Trigger a test error (for Sentry)
        </li>
        <li>
          <code>POST /api/error-events</code> — Error event receiver
        </li>
      </ul>
    </main>
  );
}
