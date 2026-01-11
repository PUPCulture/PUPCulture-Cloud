# PupCulture Bot Container

Minimal placeholder container for running a PupCulture bot behind Cloudflare Access.

Environment variables expected at runtime:

- `CF_ACCESS_CLIENT_ID` – Cloudflare Access client ID for authenticating to the PupCulture API.
- `CF_ACCESS_CLIENT_SECRET` – Cloudflare Access client secret paired with the client ID.
- `BOT_API_KEY` – API key used for bot authorization when calling the PupCulture API.
- `API_BASE_URL` – PupCulture API origin (defaults to `https://api.pupculture.site`).

You can generate a bot API key by running `node api/scripts/create-bot-api-key.mjs` from the repo root, then provide the value via `BOT_API_KEY`.

The container currently emits configuration details and a heartbeat log so it is easy to verify that Cloudflare Access credentials are being injected correctly.
