import crypto from "crypto";
import express from "express";

const app = express();
app.use(express.json());

app.use((req, res, next) => {
  if (req.path === "/health") {
    return next();
  }

  const cfClientId = req.headers["cf-access-client-id"]; // Cloudflare Access service token headers
  const cfClientSecret = req.headers["cf-access-client-secret"];
  const requireServiceToken = process.env.CF_ACCESS_REQUIRED !== "false";

  if (requireServiceToken && (!cfClientId || !cfClientSecret)) {
    return res.status(403).json({ error: "Missing service token" });
  }

  return next();
});

const singleUseTokens = new Map();
const tokenTtlMinutes = Number.parseInt(
  process.env.DISCORD_TOKEN_TTL_MINUTES ?? "10",
  10
);

function requireBotApiKey(req, res) {
  const expected = process.env.BOT_API_KEY;
  if (!expected) {
    return res
      .status(500)
      .json({ error: "Server missing BOT_API_KEY" });
  }

  const authHeader = req.headers.authorization ?? "";
  const [, token] = authHeader.split(" ");
  if (token !== expected) {
    return res.status(401).json({ error: "Invalid bot API key" });
  }

  return null;
}

function generateSingleUseToken(discordId) {
  const token = crypto.randomBytes(24).toString("hex");
  const expiresAt = Date.now() + tokenTtlMinutes * 60_000;
  singleUseTokens.set(token, { discordId, expiresAt, used: false });
  return token;
}

app.get("/health", (_, res) => res.json({ ok: true }));

app.get("/", (_, res) => {
  res.json({ service: "PupCulture API", status: "running" });
});

app.post("/discord/token", (req, res) => {
  const authError = requireBotApiKey(req, res);
  if (authError) {
    return authError;
  }

  const { discordId } = req.body ?? {};
  if (!discordId) {
    return res.status(400).json({ error: "Missing discordId" });
  }

  const token = generateSingleUseToken(String(discordId));
  return res.json({ token, expiresInMinutes: tokenTtlMinutes });
});

app.post("/discord/token/redeem", (req, res) => {
  const authError = requireBotApiKey(req, res);
  if (authError) {
    return authError;
  }

  const { token } = req.body ?? {};
  if (!token) {
    return res.status(400).json({ error: "Missing token" });
  }

  const entry = singleUseTokens.get(token);
  if (!entry) {
    return res.status(404).json({ error: "Token not found" });
  }

  if (entry.used) {
    return res.status(409).json({ error: "Token already used" });
  }

  if (Date.now() > entry.expiresAt) {
    singleUseTokens.delete(token);
    return res.status(410).json({ error: "Token expired" });
  }

  entry.used = true;
  return res.json({ discordId: entry.discordId });
});

app.listen(3001, () =>
  console.log("API listening on 3001")
);




