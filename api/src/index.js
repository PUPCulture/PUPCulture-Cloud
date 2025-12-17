import express from "express";

const app = express();
app.use(express.json());

app.get("/health", (_, res) => res.json({ ok: true }));

app.get("/", (_, res) => {
  res.json({ service: "PupCulture API", status: "running" });
});

app.listen(3001, () =>
  console.log("API listening on 3001")
);
