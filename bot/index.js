const {
  CF_ACCESS_CLIENT_ID,
  CF_ACCESS_CLIENT_SECRET,
  API_BASE_URL = 'https://api.pupculture.site',
} = process.env;

if (!CF_ACCESS_CLIENT_ID || !CF_ACCESS_CLIENT_SECRET) {
  console.warn('[bot] CF_ACCESS_CLIENT_ID or CF_ACCESS_CLIENT_SECRET is missing. Requests that require Cloudflare Access will fail.');
}

console.log('[bot] Starting with configuration:');
console.log(`- API_BASE_URL: ${API_BASE_URL}`);
console.log(`- CF_ACCESS_CLIENT_ID set: ${Boolean(CF_ACCESS_CLIENT_ID)}`);
console.log(`- CF_ACCESS_CLIENT_SECRET set: ${Boolean(CF_ACCESS_CLIENT_SECRET)}`);

setInterval(() => {
  const now = new Date().toISOString();
  console.log(`[bot] Heartbeat at ${now}`);
}, 60 * 1000);
