const {
  CF_ACCESS_CLIENT_ID,
  CF_ACCESS_CLIENT_SECRET,
  API_BASE_URL = "https://api.pupculture.site",
} = process.env;

if (!CF_ACCESS_CLIENT_ID || !CF_ACCESS_CLIENT_SECRET) {
  console.error("Missing Cloudflare Access service token. Set CF_ACCESS_CLIENT_ID and CF_ACCESS_CLIENT_SECRET.");
  process.exit(1);
}

async function sendXpEvent() {
  const payload = {
    guildId: "example-guild",
    userId: "example-user",
    action: "XP_GAIN",
  };

  const response = await fetch(`${API_BASE_URL.replace(/\/$/, "")}/bot/events`, {
    method: "POST",
    headers: {
      "CF-Access-Client-Id": CF_ACCESS_CLIENT_ID,
      "CF-Access-Client-Secret": CF_ACCESS_CLIENT_SECRET,
      "Content-Type": "application/json",
      Authorization: `Bearer ${process.env.BOT_API_KEY || ""}`,
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const body = await safeJson(response);
    throw new Error(`API blocked by Cloudflare or missing permissions: ${response.status} ${JSON.stringify(body)}`);
  }

  const body = await safeJson(response);
  console.log("Event posted", body);
}

async function safeJson(res) {
  try {
    return await res.json();
  } catch (err) {
    return null;
  }
}

sendXpEvent().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
