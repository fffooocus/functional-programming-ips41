import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const root = path.resolve(import.meta.dirname, '..');
const require = createRequire(path.join(root, '.tools', 'package.json'));
const { createCanvas, DOMMatrix, ImageData, Path2D } = require('@napi-rs/canvas');
Object.assign(globalThis, { DOMMatrix, ImageData, Path2D });
const pdfjs = await import(pathToFileURL(path.join(root, '.tools/node_modules/pdfjs-dist/legacy/build/pdf.mjs')));
fs.mkdirSync(path.join(root, '.tools/previews'), { recursive: true });
for (const lab of ['lab1','lab2','lab3']) {
  const pdf = await pdfjs.getDocument({ data: new Uint8Array(fs.readFileSync(path.join(root,lab,'report.pdf'))), useSystemFonts: true }).promise;
  let allText = '';
  const pages = [];
  for (let n = 1; n <= pdf.numPages; n++) {
    const page = await pdf.getPage(n);
    const text = await page.getTextContent();
    const pageText = text.items.map(item => item.str).join(' ');
    if (pageText.trim().length < 20) throw new Error(`${lab} contains a blank page: ${n}`);
    allText += pageText;
    if (pageText.includes('\ufffd')) throw new Error(`${lab} contains replacement characters`);
    if (text.items.some(item => item.str.trim() && item.transform[4] > 560)) throw new Error(`${lab} text overflows right margin`);
    const viewport = page.getViewport({ scale: .65 });
    const canvas = createCanvas(Math.ceil(viewport.width), Math.ceil(viewport.height));
    await page.render({ canvasContext: canvas.getContext('2d'), viewport }).promise;
    pages.push(canvas);
  }
  if (!allText.includes('Левківський Євгеній Сергійович') || !allText.includes('ІПС-41')) throw new Error(`Missing author in ${lab}`);
  const thumb = createCanvas(pages[0].width * 3, pages[0].height * Math.ceil(pages.length/3));
  const context = thumb.getContext('2d');
  context.fillStyle = '#d1d5db'; context.fillRect(0,0,thumb.width,thumb.height);
  pages.forEach((page, i) => context.drawImage(page, (i%3)*page.width, Math.floor(i/3)*page.height));
  fs.writeFileSync(path.join(root,'.tools/previews',`${lab}.png`), thumb.toBuffer('image/png'));
  console.log(`${lab}: ${pdf.numPages} pages; Unicode, author and margins OK`);
  await pdf.destroy();
}
