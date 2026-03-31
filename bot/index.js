const {
  CF_ACCESS_CLIENT_ID,
  CF_ACCESS_CLIENT_SECRET,
  BOT_API_KEY,
  API_BASE_URL = "http://api:3001",
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

async function requestSingleUseToken(discordId) {
  const res = await fetch(`${API_BASE_URL}/discord/token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "CF-Access-Client-Id": CF_ACCESS_CLIENT_ID,
      "CF-Access-Client-Secret": CF_ACCESS_CLIENT_SECRET,
      "Authorization": `Bearer ${BOT_API_KEY}`,
    },
    body: JSON.stringify({ discordId }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`API rejected request: ${res.status} ${text}`);
  }

  const data = await res.json();
  console.log("✅ Single-use token generated:", data);
}

const discordId = process.env.DISCORD_ID ?? "example-discord-user";
requestSingleUseToken(discordId).catch((err) => {
  console.error("❌ Bot error:", err.message);
  process.exit(1);
});
