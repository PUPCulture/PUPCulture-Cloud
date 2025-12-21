import express from "express";

const app = express();
app.use(express.json());

app.use((req, res, next) => {
  const cfClientId = req.headers["cf-access-client-id"]; // Cloudflare Access service token header

  if (!cfClientId) {
    return res.status(403).json({ error: "Missing service token" });
  }

  return next();
});

app.get("/health", (_, res) => res.json({ ok: true }));

app.get("/", (_, res) => {
  res.json({ service: "PupCulture API", status: "running" });
});

app.listen(3001, () =>
  console.log("API listening on 3001")
);
