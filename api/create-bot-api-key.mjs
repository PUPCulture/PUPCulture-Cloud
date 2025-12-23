import crypto from "crypto";
import pkg from "pg";

const { Pool } = pkg;

const pool = new Pool({
  host: process.env.POSTGRES_HOST || "db",
  port: 5432,
  user: process.env.POSTGRES_USER || "pupculture",
  password: process.env.POSTGRES_PASSWORD || "pupculture",
  database: process.env.POSTGRES_DB || "pupculture",
});

const apiKey = "bot_" + crypto.randomBytes(32).toString("hex");

async function run() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS api_keys (
      id SERIAL PRIMARY KEY,
      key TEXT UNIQUE NOT NULL,
      label TEXT,
      created_at TIMESTAMPTZ DEFAULT now()
    );
  `);

  await pool.query(
    "INSERT INTO api_keys (key, label) VALUES ($1, $2)",
    [apiKey, "discord-bot"]
  );

  console.log("\n✅ BOT_API_KEY CREATED\n");
  console.log(apiKey);
  console.log("\nSave this. You will not see it again.\n");

  process.exit(0);
}

run().catch((err) => {
  console.error("❌ Failed to create API key:", err);
  process.exit(1);
});
