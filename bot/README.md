# PupCulture Bot Container

Minimal placeholder container for running a PupCulture bot behind Cloudflare Access.

Environment variables expected at runtime:

- `CF_ACCESS_CLIENT_ID` – Cloudflare Access client ID for authenticating to the PupCulture API.
- `CF_ACCESS_CLIENT_SECRET` – Cloudflare Access client secret paired with the client ID.
- `API_BASE_URL` – PupCulture API origin (defaults to `https://api.pupculture.site`).

The container currently emits configuration details and a heartbeat log so it is easy to verify that Cloudflare Access credentials are being injected correctly.
