import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const root = path.resolve(import.meta.dirname, '..');
const require = createRequire(path.join(root, '.tools', 'package.json'));
const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  WidthType, AlignmentType, Footer, PageNumber, BorderStyle } = require('docx');
const PDFDocument = require('pdfkit');
const author = 'Левківський Євгеній Сергійович';

function parse(markdown) {
  const lines = markdown.split(/\r?\n/);
  const blocks = [];
  for (let i = 0; i < lines.length;) {
    const line = lines[i];
    if (!line.trim()) { i++; continue; }
    if (line === '<!-- pagebreak -->') { blocks.push({ type: 'break' }); i++; continue; }
    if (line.startsWith('```')) {
      const text = [];
      for (i++; i < lines.length && !lines[i].startsWith('```'); i++) text.push(lines[i]);
      i++;
      blocks.push({ type: 'code', text: text.join('\n') });
      continue;
    }
    if (line.startsWith('|')) {
      const rows = [];
      while (i < lines.length && lines[i].startsWith('|')) {
        if (!/^\|[\s:|\-]+\|$/.test(lines[i])) rows.push(lines[i].split('|').slice(1, -1).map(cell => cell.trim()));
        i++;
      }
      blocks.push({ type: 'table', rows });
      continue;
    }
    if (line.startsWith('#')) {
      blocks.push({ type: line.startsWith('##') ? 'heading' : 'title', text: line.replace(/^#+\s*/, '') });
      i++;
      continue;
    }
    const text = [line];
    for (i++; i < lines.length && lines[i].trim() && !/^(#|\||```|<!--)/.test(lines[i]); i++) text.push(lines[i]);
    blocks.push({ type: 'paragraph', text: text.join(' ') });
  }
  return blocks;
}

async function docx(blocks, destination) {
  let titlePage = true;
  const paragraphs = [];
  for (const block of blocks) {
    if (block.type === 'break') {
      titlePage = false;
      paragraphs.push(new Paragraph({ pageBreakBefore: true, children: [] }));
    } else if (block.type === 'table') {
      paragraphs.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE },
        rows: block.rows.map((row, index) => new TableRow({ tableHeader: index === 0, cantSplit: true,
          children: row.map(text => new TableCell({
            shading: index === 0 ? { fill: 'EDF0F2' } : undefined,
            margins: { top: 80, bottom: 80, left: 100, right: 100 },
            children: [new Paragraph({ keepNext: index < block.rows.length - 1, spacing: { line: 260, after: 0 }, children: [new TextRun({ text, size: 22, bold: index === 0 })] })],
          })) })) }));
      paragraphs.push(new Paragraph({ children: [] }));
    } else if (block.type === 'code') {
      for (const line of block.text.split('\n')) paragraphs.push(new Paragraph({
        spacing: { line: 240, after: 0 }, shading: { fill: 'F5F5F5' },
        children: [new TextRun({ text: line || ' ', font: 'Consolas', size: 19 })],
      }));
      paragraphs.push(new Paragraph({ children: [] }));
    } else {
      const heading = block.type === 'heading';
      const title = block.type === 'title';
      paragraphs.push(new Paragraph({
        alignment: titlePage ? AlignmentType.CENTER : (heading ? AlignmentType.LEFT : AlignmentType.JUSTIFIED),
        keepNext: heading,
        spacing: { line: 360, before: title ? 1600 : (heading ? 220 : 0), after: titlePage ? 480 : 120 },
        indent: !titlePage && !heading ? { firstLine: 709 } : undefined,
        children: [new TextRun({ text: block.text, size: title ? 36 : (heading ? 30 : 28), bold: heading || title })],
      }));
    }
  }
  const document = new Document({ creator: author, title: blocks[0].text,
    description: 'Функціональне програмування. ІПС-41.',
    styles: { default: { document: { run: { font: 'Times New Roman', size: 28 } } } },
    sections: [{ properties: { titlePage: true,
      page: { size: { width: 11906, height: 16838 }, margin: { top: 1134, bottom: 1134, left: 1701, right: 850 } } },
      footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER,
        children: [new TextRun({ children: [PageNumber.CURRENT], size: 22 })] })] }) },
      children: paragraphs }],
  });
  fs.writeFileSync(destination, await Packer.toBuffer(document));
}

async function pdf(blocks, destination) {
  const doc = new PDFDocument({ size: 'A4', margins: { top: 56.7, bottom: 56.7, left: 85, right: 42.5 },
    bufferPages: true, info: { Title: blocks[0].text, Author: author, Subject: 'Функціональне програмування. ІПС-41.' } });
  const stream = fs.createWriteStream(destination);
  doc.pipe(stream);
  doc.registerFont('body', 'C:/Windows/Fonts/times.ttf');
  doc.registerFont('bold', 'C:/Windows/Fonts/timesbd.ttf');
  doc.registerFont('code', 'C:/Windows/Fonts/consola.ttf');
  let titlePage = true;
  const width = doc.page.width - 127.5;
  const bottom = () => doc.page.height - 56.7;
  for (const block of blocks) {
    if (block.type === 'break') { titlePage = false; doc.addPage(); continue; }
    if (block.type === 'table') {
      const columns = block.rows[0].length;
      const widths = Array.from({ length: columns }, (_, i) => columns === 2 ? width * (i ? .64 : .36) : width / columns);
      const heights = block.rows.map((row,index) => {
        doc.font(index ? 'body' : 'bold').fontSize(11);
        return Math.max(...row.map((text,i) => doc.heightOfString(text,{width:widths[i]-12,lineGap:2})))+14;
      });
      const totalHeight = heights.reduce((a,b) => a+b,0);
      if (totalHeight < bottom()-56.7 && doc.y+totalHeight > bottom()) doc.addPage();
      for (let index = 0; index < block.rows.length; index++) {
        doc.font(index ? 'body' : 'bold').fontSize(11);
        const row = block.rows[index];
        const height = heights[index];
        if (doc.y + height > bottom()) doc.addPage();
        const top = doc.y;
        let left = 85;
        for (let i = 0; i < columns; i++) {
          doc.save().lineWidth(.5).strokeColor('#9ca3af');
          if (!index) doc.rect(left, top, widths[i], height).fillAndStroke('#edf0f2', '#9ca3af');
          else doc.rect(left, top, widths[i], height).stroke();
          doc.restore();
          doc.fillColor('black').text(row[i], left + 6, top + 7, { width: widths[i] - 12, lineGap: 2 });
          left += widths[i];
        }
        doc.x = 85;
        doc.y = top + height;
      }
      doc.y += 12;
      continue;
    }
    if (block.type === 'code') {
      doc.font('code').fontSize(10);
      const height = doc.heightOfString(block.text, { width, lineGap: 2 });
      if (height < bottom() - 56.7 && doc.y + height > bottom()) doc.addPage();
      doc.text(block.text, { width, lineGap: 2 });
      doc.moveDown(.8);
      continue;
    }
    if (titlePage) {
      if (block.type === 'title') doc.y = 165;
      doc.font(block.type === 'title' ? 'bold' : 'body').fontSize(block.type === 'title' ? 21 : 16)
        .text(block.text, { width, align: 'center', lineGap: 6 });
      doc.moveDown(1.8);
    } else if (block.type === 'heading') {
      if (doc.y + 80 > bottom()) doc.addPage();
      doc.moveDown(.5);
      doc.font('bold').fontSize(15).text(block.text, { width, lineGap: 3 });
      doc.moveDown(.5);
    } else {
      doc.font('body').fontSize(14).text(block.text, { width, align: 'justify', lineGap: 5, indent: 25 });
      doc.moveDown(.5);
    }
  }
  const pages = doc.bufferedPageRange().count;
  for (let index = 1; index < pages; index++) {
    doc.switchToPage(index);
    const margin = doc.page.margins.bottom;
    doc.page.margins.bottom = 0;
    doc.font('body').fontSize(11).text(String(index + 1), 85, doc.page.height - 38,
      { width, align: 'center', lineBreak: false });
    doc.page.margins.bottom = margin;
  }
  doc.end();
  await new Promise((resolve, reject) => { stream.on('finish', resolve); stream.on('error', reject); });
  return pages;
}

for (const lab of ['lab1', 'lab2', 'lab3']) {
  const blocks = parse(fs.readFileSync(path.join(root, lab, 'report.md'), 'utf8'));
  await docx(blocks, path.join(root, lab, 'report.docx'));
  const pages = await pdf(blocks, path.join(root, lab, 'report.pdf'));
  console.log(`${lab}: DOCX, PDF (${pages} pages)`);
}
