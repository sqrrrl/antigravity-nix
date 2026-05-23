#!/usr/bin/env node
const { chromium } = require('playwright-chromium');

async function scrapeVersion() {
  console.error('[INFO] Launching browser...');

  const chromePath = process.env.CHROME_BIN ||
                     process.env.CHROME_PATH ||
                     '/run/current-system/sw/bin/google-chrome-stable';

  const fs = require('fs');
  const useSystemChrome = fs.existsSync(chromePath);

  const browser = await chromium.launch({
    headless: true,
    ...(useSystemChrome && { executablePath: chromePath }),
  });

  try {
    const page = await browser.newPage();

    console.error('[INFO] Navigating to Antigravity download page...');
    await page.goto('https://antigravity.google/download', {
      waitUntil: 'networkidle',
      timeout: 30000,
    });

    console.error('[INFO] Waiting for page to render...');
    await page.waitForTimeout(3000);

    const downloadLinks = await page.$$eval('a', as => as.map(a => a.href));

    const ide_version = downloadLinks
        .find(href => href.includes('linux-x64/Antigravity%20IDE.tar.gz'))
        ?.match(/antigravity\/stable\/([0-9.]+-[0-9]+)/)?.[1];

    const hub_version = downloadLinks
        .find(href => href.includes('linux-x64/Antigravity.tar.gz') && href.includes('storage.googleapis.com'))
        ?.match(/antigravity-hub\/([0-9.]+-[0-9]+)/)?.[1];

    let cli_version = null;
    try {
        const manifestRes = await fetch('https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json');
        const manifest = await manifestRes.json();
        cli_version = manifest.url.match(/antigravity-cli\/([0-9.]+-[0-9]+)/)?.[1];
    } catch (e) {
        console.error('[ERROR] Could not fetch CLI manifest:', e.message);
    }

    if (ide_version && hub_version && cli_version) {
      console.error(`[SUCCESS] Found versions: IDE=${ide_version}, Hub=${hub_version}, CLI=${cli_version}`);
      console.log(JSON.stringify({
        ide: ide_version,
        hub: hub_version,
        cli: cli_version
      }));
      return;
    } else {
      console.error(`[ERROR] Missing some versions. IDE=${ide_version}, Hub=${hub_version}, CLI=${cli_version}`);
      process.exit(1);
    }
  } catch (error) {
    console.error(`[ERROR] ${error.message}`);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

scrapeVersion().catch(error => {
  console.error(`[FATAL] ${error.message}`);
  process.exit(1);
});
