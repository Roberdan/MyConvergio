#!/usr/bin/env node
// Record dashboard demo — screenshot sequence + ffmpeg (no recordVideo)
import { chromium } from '/tmp/node_modules/playwright/index.mjs';
import { execSync } from 'child_process';
import { mkdirSync } from 'fs';

const URL = 'http://localhost:8420';
const DURATION = parseInt(process.env.DURATION || '90', 10);
const FPS = 2;
const FRAMES_DIR = '/tmp/demo-frames';
const OUTPUT = '/tmp/hyperDemo-dashboard.mp4';

(async () => {
  mkdirSync(FRAMES_DIR, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  // NO recordVideo — that causes crashes
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });

  page.on('pageerror', () => {}); // suppress JS errors
  console.log(`Recording ${DURATION}s at ${FPS}fps...`);
  await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: 15000 });
  await page.waitForTimeout(1500);
  await page.evaluate(() => localStorage.setItem('dashRefresh', '5'));

  const totalFrames = DURATION * FPS;
  const phaseFrames = Math.floor(totalFrames / 4);
  const sections = ['overview', 'brain', 'mesh', 'overview'];
  const interval = Math.floor(1000 / FPS);

  for (let f = 0; f < totalFrames; f++) {
    const phase = Math.floor(f / phaseFrames);
    if (f > 0 && f % phaseFrames === 0 && phase < sections.length) {
      console.log(`→ Phase ${phase + 1}: ${sections[phase]}`);
      await page.evaluate(s => {
        const el = document.querySelector(`[data-section="${s}"]`);
        if (el) el.click();
      }, sections[phase]);
      await page.waitForTimeout(600);
    }
    const num = String(f).padStart(5, '0');
    try {
      await page.screenshot({ path: `${FRAMES_DIR}/frame-${num}.png` });
    } catch (e) {
      console.log(`  Skip frame ${f}: ${e.message}`);
    }
    if (f % 30 === 0) console.log(`  Frame ${f}/${totalFrames}`);
    await page.waitForTimeout(interval);
  }

  await browser.close();
  console.log('Stitching with ffmpeg...');
  try {
    execSync(`ffmpeg -y -framerate ${FPS} -i ${FRAMES_DIR}/frame-%05d.png -c:v libx264 -pix_fmt yuv420p -crf 23 -preset fast ${OUTPUT} 2>/dev/null`);
    console.log(`✓ Video: ${OUTPUT}`);
  } catch (e) {
    console.error('ffmpeg failed:', e.message);
  }
})().catch(e => { console.error(e); process.exit(1); });
