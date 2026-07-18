// Attach to the existing hackathon CDP browser (isolated Brave, port 9230) and
// drive the Discord Developer Portal in a tab that SHARES the profile session.
// Never launches a browser; only attaches. Reads token via the page clipboard
// so the value is written to a file by the caller, not printed.
//
// Usage:
//   node discord-token.mjs check      # report dev-portal login state (default)
//   node discord-token.mjs list       # list applications (names + ids)
//   node discord-token.mjs shot PATH  # screenshot current dev-portal tab
//
// CDP endpoint comes from HACKATHON_CDP_URL or defaults to 127.0.0.1:9230.
import { createRequire } from 'node:module';
// Resolve Playwright from the global install (path-agnostic: honor NODE_PATH,
// fall back to the caller-provided PLAYWRIGHT_DIR, else a bare require).
const require = createRequire(import.meta.url);
function loadChromium() {
  const candidates = [
    process.env.PLAYWRIGHT_DIR && `${process.env.PLAYWRIGHT_DIR}/playwright`,
    ...(process.env.NODE_PATH ? process.env.NODE_PATH.split(':').map((d) => `${d}/playwright`) : []),
    'playwright',
  ].filter(Boolean);
  for (const c of candidates) {
    try { return require(c).chromium; } catch { /* try next */ }
  }
  throw new Error('playwright not found (set NODE_PATH or PLAYWRIGHT_DIR)');
}
const chromium = loadChromium();

const CDP = process.env.HACKATHON_CDP_URL || 'http://127.0.0.1:9230';
const cmd = process.argv[2] || 'check';
const arg = process.argv[3];

const browser = await chromium.connectOverCDP(CDP);
const ctx = browser.contexts()[0];

// Reuse an existing developer-portal tab if one is open; otherwise open a new
// tab in the SAME context (shares cookies/session with your logged-in profile).
let page = ctx.pages().find((p) => p.url().includes('discord.com/developers'));
const reused = Boolean(page);
if (!page) page = await ctx.newPage();

async function gotoPortal() {
  await page.goto('https://discord.com/developers/applications', {
    waitUntil: 'domcontentloaded',
    timeout: 45000,
  });
  // Let the SPA hydrate and any auth pass-through settle.
  await page.waitForTimeout(3500);
}

async function loginState() {
  // The static <title> is always "My Applications", so it is NOT a signal.
  // The gate modal heading "Welcome to the Developer Portal" is the real one.
  const gated = await page
    .getByText('Welcome to the Developer Portal', { exact: false })
    .count()
    .catch(() => 0);
  const url = page.url();
  const onLogin = url.includes('/login');
  return { loggedIn: gated === 0 && !onLogin, gated, url };
}

async function createApp(name) {
  await gotoPortal();
  const st = await loginState();
  if (!st.loggedIn) return { ok: false, reason: 'not-logged-in', ...st };
  await page.getByRole('button', { name: 'New Application' }).first().click();
  await page.waitForTimeout(1200);
  // Name field inside the dialog.
  const nameBox = page.getByRole('textbox').first();
  await nameBox.click();
  await nameBox.fill(name);
  // ToS agreement: the styled checkbox can swallow a direct input click, so try
  // check(force), then fall back to clicking the agreement label text.
  const createBtn = page.getByRole('button', { name: 'Create' }).first();
  const cb = page.locator('input[type=checkbox]').first();
  if (await cb.count()) await cb.check({ force: true }).catch(() => {});
  await page.waitForTimeout(300);
  if (await createBtn.isDisabled().catch(() => true)) {
    await page.getByText('By clicking Create', { exact: false }).click().catch(() => {});
    await page.waitForTimeout(300);
  }
  if (await createBtn.isDisabled().catch(() => true)) {
    await page.screenshot({ path: '/tmp/claude-1000/create-blocked.png' }).catch(() => {});
    return { ok: false, reason: 'create-still-disabled', url: page.url() };
  }
  await createBtn.click();
  await page.waitForTimeout(3500);
  const url = page.url();
  const m = url.match(/applications\/(\d+)/);
  return { ok: Boolean(m), id: m ? m[1] : null, url };
}

if (cmd === 'shot') {
  const out = arg || '/tmp/claude-1000/discord-portal.png';
  await page.screenshot({ path: out });
  console.log(JSON.stringify({ ok: true, screenshot: out, url: page.url() }));
} else if (cmd === 'list') {
  await gotoPortal();
  const st = await loginState();
  if (!st.loggedIn) {
    console.log(JSON.stringify({ ok: false, reason: 'not-logged-in', ...st }));
  } else {
    // Application cards link to /developers/applications/<id>/...
    const apps = await page.$$eval('a[href*="/developers/applications/"]', (as) => {
      const seen = {};
      for (const a of as) {
        const m = a.getAttribute('href').match(/applications\/(\d+)/);
        if (m) seen[m[1]] = (a.textContent || '').trim() || seen[m[1]] || '';
      }
      return Object.entries(seen).map(([id, name]) => ({ id, name }));
    });
    console.log(JSON.stringify({ ok: true, reused, apps }));
  }
} else if (cmd === 'create') {
  const name = arg || 'team-ops-bot';
  console.log(JSON.stringify(await createApp(name)));
} else {
  // check
  await gotoPortal();
  const st = await loginState();
  console.log(JSON.stringify({ ok: true, reused, ...st }));
}

await browser.close(); // detaches the CDP connection; does NOT close the browser
