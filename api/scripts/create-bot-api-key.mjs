import crypto from "crypto";
import fs from "fs";

const KEY_FILE = "/app/.bot_api_key";

if (fs.existsSync(KEY_FILE)) {
  console.log("ℹ️ BOT_API_KEY already exists:");
  console.log(fs.readFileSync(KEY_FILE, "utf8"));
  process.exit(0);
}

const key = "bot_" + crypto.randomBytes(32).toString("hex");
fs.writeFileSync(KEY_FILE, key, { mode: 0o600 });

console.log("✅ BOT_API_KEY CREATED");
console.log(key);