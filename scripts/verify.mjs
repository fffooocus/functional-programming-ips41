import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '..');
process.chdir(root);
const win = process.platform === 'win32';
const exe = lab => path.join(root, '.build', win ? `${lab}.exe` : `${lab}-run`);
const output = path.join(root, 'verification');
fs.mkdirSync(output, { recursive: true });
let transcript = '';
function run(lab, args, { env = process.env, fail = false } = {}) {
  const result = spawnSync(exe(lab), args, { encoding: 'utf8', env, maxBuffer: 32 * 1024 * 1024 });
  if (result.error) throw result.error;
  if (fail) assert.notEqual(result.status, 0, 'Expected command failure');
  else assert.equal(result.status, 0, result.stderr);
  transcript += `$ ${lab} ${args.join(' ')}\n${result.stdout}${result.stderr}\n`;
  return result.stdout;
}

const metadata = { timestamp: new Date().toISOString(), platform: os.platform(),
  architecture: os.arch(), cpu: os.cpus()[0].model.trim(), logical_processors: os.cpus().length,
  node: process.version, ghc: '9.6.7', compiler_flags: '-O2 -Wall -threaded -rtsopts' };
fs.writeFileSync(path.join(output, 'environment.json'), JSON.stringify(metadata, null, 2) + '\n');

const analysis = run('lab3', ['lab3/examples/textbook.txt', '--output', 'lab3/results.txt']);
assert.match(analysis, /Найбільша кількість речень зі спільним словом: 5/);
fs.writeFileSync(path.join(output, 'lab3.txt'), transcript.trimEnd() + '\n');
transcript = '';

const temporary = fs.mkdtempSync(path.join(root, '.build', 'roundtrip-'));
const examples = [['empty.bin', Buffer.alloc(0)], ['one.bin', Buffer.alloc(2048, 42)],
  ['all-bytes.bin', Buffer.from(Array.from({ length: 256 }, (_, i) => i))],
  ['українська.txt', Buffer.from('Haskell обробляє український текст.\n'.repeat(1000))]];
for (const [name, bytes] of examples) fs.writeFileSync(path.join(temporary, name), bytes);
const archive1 = path.join(temporary, 'one.hfar');
const archive4 = path.join(temporary, 'four.hfar');
const files = examples.map(([name]) => path.join(temporary, name));
run('lab2', ['pack', '1', archive1, ...files, '+RTS', '-N1', '-RTS']);
run('lab2', ['pack', '4', archive4, ...files, '+RTS', '-N4', '-RTS']);
assert.deepEqual(fs.readFileSync(archive1), fs.readFileSync(archive4));
run('lab2', ['list', archive4]);
const restored = path.join(temporary, 'restored');
run('lab2', ['unpack', archive4, restored]);
for (const [name, bytes] of examples) assert.deepEqual(fs.readFileSync(path.join(restored, name)), bytes);
run('lab2', ['unpack', archive4, restored], { fail: true });
run('lab2', ['pack', '0', path.join(temporary, 'bad.hfar'), ...files], { fail: true });
const corrupt = Buffer.from(fs.readFileSync(archive4));
corrupt[corrupt.length - 2] ^= 0xff;
const badArchive = path.join(temporary, 'corrupt.hfar');
fs.writeFileSync(badArchive, corrupt);
run('lab2', ['unpack', badArchive, path.join(temporary, 'bad-output')], { fail: true });
assert.ok(!fs.existsSync(path.join(temporary, 'bad-output')), 'Corrupt archive must not write output');
fs.writeFileSync(path.join(output, 'lab2.txt'), transcript.replaceAll(temporary, '<temporary-directory>').trimEnd() + '\n');
transcript = '';

if (process.env.MYSQL_BIN) {
  const before = run('lab1', ['list']);
  assert.match(before, /Haskell/);
  run('lab1', ['catalog']);
  run('lab1', ['search', 'Haskell']);
  run('lab1', ['details', '1']);
  run('lab1', ['stats']);
  const title = "Перевірка ' SQL; --";
  const added = run('lab1', ['add', title, 'Тест\tтабуляції\nта нового рядка', '1', '1', '2026-10-01', '-']);
  const id = added.match(/Created resource (\d+)/)[1];
  assert.match(run('lab1', ['search', title]), /Перевірка/);
  assert.equal(run('lab1', ['search', "' OR 1=1 --"]).trim(), '');
  run('lab1', ['update', id, 'Оновлений ресурс', 'Оновлена анотація', '2', '2', '2026-10-01', '2027-06-30']);
  assert.match(run('lab1', ['search', 'Оновлений ресурс']), /Оновлений ресурс/);
  run('lab1', ['link-author', id, '3']);
  run('lab1', ['link-purpose', id, '2']);
  run('lab1', ['url-add', id, 'https://example.org/resource']);
  run('lab1', ['edit', 'authors', '3', 'name', 'Левківський Євгеній Сергійович']);
  run('lab1', ['edit', 'authors;DROP TABLE users', '3', 'name', 'bad'], { fail: true });
  run('lab1', ['grant', id, '1']);
  run('lab1', ['visit', id, '1', '90']);
  assert.match(run('lab1', ['stats']), /Оновлений ресурс \| 1 \| 1 \| 90/);
  run('lab1', ['add', 'Bad', 'Bad', '1', '1', '2026-02-30', '-'], { fail: true });
  run('lab1', ['add', 'Bad FK', 'Bad', '999999', '1', '2026-10-01', '-'], { fail: true });
  run('lab1', ['update', '999999', 'Missing', 'Missing', '1', '1', '2026-10-01', '-'], { fail: true });
  run('lab1', ['delete', id]);
  assert.equal(run('lab1', ['search', 'Оновлений ресурс']).trim(), '');
  const stats = run('lab1', ['stats']);
  assert.ok(!stats.includes('Оновлений ресурс'));
  fs.writeFileSync(path.join(output, 'lab1.txt'), transcript.trimEnd() + '\n');
} else {
  console.log('MySQL integration skipped: set MYSQL_BIN to enable.');
}
console.log('CLI integration checks passed.');
