const {
  CF_ACCESS_CLIENT_ID,
  CF_ACCESS_CLIENT_SECRET,
  BOT_API_KEY,
  API_BASE_URL = "https://api.pupculture.site",
} = process.env;

function requireEnv(name) {
  if (!process.env[name]) {
    console.error(`❌ Missing required environment variable: ${name}`);
    process.exit(1);
  }
}

requireEnv("CF_ACCESS_CLIENT_ID");
requireEnv("CF_ACCESS_CLIENT_SECRET");
requireEnv("BOT_API_KEY");

async function sendXpEvent() {
  const payload = {
    guildId: "example-guild",
    userId: "example-user",
    action: "XP_GAIN",
  };

  const res = await fetch(`${API_BASE_URL}/bot/events`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "CF-Access-Client-Id": CF_ACCESS_CLIENT_ID,
      "CF-Access-Client-Secret": CF_ACCESS_CLIENT_SECRET,
      "Authorization": `Bearer ${BOT_API_KEY}`,
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`API rejected request: ${res.status} ${text}`);
  }

  console.log("✅ XP event sent");
}

sendXpEvent().catch((err) => {
  console.error("❌ Bot error:", err.message);
  process.exit(1);
});
