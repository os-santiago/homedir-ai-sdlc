// Trusted browser probe. Input is rendered HTML/CSS data, never JavaScript tests.
const fs = require('node:fs');
const crypto = require('node:crypto');
const { chromium } = require('playwright');

async function main() {
  const raw = fs.readFileSync(0);
  if (raw.length > 1024 * 1024) throw new Error('input limit');
  const input = JSON.parse(raw);
  if (Object.keys(input).sort().join(',') !== 'css,html' ||
      typeof input.html !== 'string' || typeof input.css !== 'string') throw new Error('input schema');
  const inputHash = crypto.createHash('sha256').update(raw).digest('hex');
  const browser = await chromium.launch({ chromiumSandbox: true, timeout: 10000 });
  const measurements = [];
  try {
    for (const width of [1024, 375]) {
      const context = await browser.newContext({ viewport: { width, height: 900 },
        javaScriptEnabled: false, serviceWorkers: 'block', acceptDownloads: false });
      await context.route('**/*', route => route.abort());
      const page = await context.newPage();
      page.setDefaultTimeout(5000);
      await page.setContent(input.html, { waitUntil: 'domcontentloaded', timeout: 5000 });
      // addStyleTag waits on page-side events, which cannot run when scripts are
      // disabled. Inject text synchronously through trusted instrumentation.
      await page.evaluate(css => {
        const style = document.createElement('style');
        style.textContent = css;
        document.head.appendChild(style);
      }, input.css);
      // Script execution in the document is disabled. This evaluator is trusted
      // Playwright instrumentation, not code taken from the candidate.
      const results = await page.evaluate(() => {
        const rows = [...document.querySelectorAll('.hub-list-item')];
        if (!rows.length || rows.length > 100) return [{ check: 'row-count', passed: false }];
        const checks = [];
        for (const [index, row] of rows.entries()) {
          const member = row.querySelector('.hub-member');
          const score = row.querySelector('.hub-score');
          const name = member?.querySelector('.hub-member-link, span:not(.hub-handle)');
          if (!name || !score) {
            checks.push({ row: index, check: 'required-elements', passed: false });
            continue;
          }
          const original = name.textContent.trim();
          const accessible = name.getAttribute('title') === original || name.getAttribute('aria-label') === original;
          const rect = el => { const r = el.getBoundingClientRect(); return { x: r.x, y: r.y, right: r.right, width: r.width, height: r.height }; };
          name.textContent = 'Null';
          const shortRow = rect(row), shortScore = rect(score);
          name.textContent = 'VeryLongCommunityContributorNameWithoutSpaces'.repeat(3);
          const longRow = rect(row), nameBox = rect(name), scoreBox = rect(score), style = getComputedStyle(name);
          checks.push({ row: index, check: 'full-name-accessible', passed: accessible });
          checks.push({ row: index, check: 'visible-content', passed:
            name.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true }) &&
            score.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true }) && nameBox.height > 0 });
          checks.push({ row: index, check: 'ellipsis', passed: style.textOverflow === 'ellipsis' &&
            style.overflowX === 'hidden' && style.whiteSpace === 'nowrap' && name.scrollWidth > name.clientWidth && nameBox.width > 0 });
          checks.push({ row: index, check: 'no-collision', passed: nameBox.right <= scoreBox.x + 1 &&
            scoreBox.width > 0 && scoreBox.right <= longRow.right + 1 });
          checks.push({ row: index, check: 'score-stable', passed: Math.abs(shortScore.right - scoreBox.right) <= 1 &&
            Math.abs(shortScore.width - scoreBox.width) <= 1 });
          checks.push({ row: index, check: 'row-height-stable', passed: Math.abs(shortRow.height - longRow.height) <= 1 });
        }
        checks.push({ check: 'no-horizontal-overflow', passed: document.documentElement.scrollWidth <= innerWidth + 1 });
        return checks;
      });
      measurements.push({ width, checks: results });
      await context.close();
    }
  } finally { await browser.close(); }
  const passed = measurements.every(view => view.checks.every(check => check.passed));
  process.stdout.write(JSON.stringify({ schema: 1, validator: 'reputation-hub-layout-v1',
    input_sha256: inputHash, passed, measurements }) + '\n');
  process.exitCode = passed ? 0 : 1;
}

main().catch(() => {
  // Do not leak candidate HTML, browser logs, filesystem paths or environment.
  process.stdout.write(JSON.stringify({ schema: 1, validator: 'reputation-hub-layout-v1', passed: false, error: 'validator-runtime-failure' }) + '\n');
  process.exitCode = 2;
});
