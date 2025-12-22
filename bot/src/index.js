/**
 * PupCulture Bot → API Client
 * Node.js 18+ (native fetch)
 * Cloudflare Zero Trust + API Key auth
 */

// ===============================
// ENVIRONMENT
// ===============================

const {
  CF_ACCESS_CLIENT_ID,
  CF_ACCESS_CLIENT_SECRET,
  BOT_API_KEY,
  API_BASE_URL = "https://api.pupculture.site",
} = process.env;

// ===============================
// HARD FAILS (NO SILENT MISERY)
// ===============================

function requireEnv(name, value) {
  if (!value) {
    console.error(`❌ Missing required environment variable: ${name}`);
    process.exit(1);
  }
}

requireEnv("CF_ACCESS_CLIENT_ID", CF_ACCESS_CLIENT_ID);
requireEnv("CF_ACCESS_CLIENT_SECRET", CF_ACCESS_CLIENT_SECRET);
requireEnv("BOT_API_KEY", BOT_API_KEY);

// ===============================
// HELPERS
// ===============================

async function readBody(res) {
  const text = await res.text();
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function isCloudflareHtml(body) {
  return typeof body === "string" && body.toLowerCase().includes("<html");
}

// ===============================
// CORE API CALL
// ===============================

async function sendXpEvent() {
  const payload = {
    guildId: "example-guild",
    userId: "example-user",
    action: "XP_GAIN",
    timestamp: new Date().toISOString(),
  };

  const url =
    API_BASE_URL.replace(/\/$/, "") +
    "/bot/events";

  const response = await fetch(url, {
    method: "POST",
    headers: {
      // 🔐 Cloudflare Zero Trust (machine identity)
      "CF-Access-Client-Id": CF_ACCESS_CLIENT_ID,
      "CF-Access-Client-Secret": CF_ACCESS_CLIENT_SECRET,

      // 🔑 Application authorization
      "Authorization": `Bearer ${BOT_API_KEY}`,

      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const body = await readBody(response);

    if (isCloudflareHtml(body)) {
      throw new Error(
        `❌ BLOCKED BY CLOUDFLARE (${response.status})\n` +
        `→ Check Zero Trust Access policy\n` +
        `→ Service Auth MUST be allowed`
      );
    }

    throw new Error(
      `❌ API ERROR (${response.status})\n` +
      `${JSON.stringify(body, null, 2)}`
    );
  }

  const result = await readBody(response);
  console.log("✅ Event successfully posted:");
  console.log(result);
}

// ===============================
// ENTRY POINT
// ===============================

(async () => {
  try {
    await sendXpEvent();
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
})();
