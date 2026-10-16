import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
process.chdir(root);
const dir = path.join(root, 'lab2', 'benchmark-data');
fs.mkdirSync(dir, { recursive: true });
const text = fs.readFileSync('lab3/examples/textbook.txt');
const inputs = [];
for (let file = 0; file < 8; file++) {
  const target = path.join(dir, `chapter-${file + 1}.txt`);
  const size = 1024 * 1024;
  const bytes = Buffer.alloc(size);
  for (let offset = 0; offset < size; offset += text.length) text.copy(bytes, offset);
  fs.writeFileSync(target, bytes);
  inputs.push(target);
}
const executable = process.platform === 'win32' ? '.build/lab2.exe' : '.build/lab2-run';
const child = spawn(executable, ['benchmark', '4', ...inputs, '+RTS', '-N4', '-RTS'], { stdio: ['ignore', 'pipe', 'inherit'] });
let result = '';
child.stdout.on('data', data => { result += data.toString(); process.stdout.write(data); });
child.on('error', error => { throw error; });
child.on('exit', code => {
  if (code !== 0) { process.exitCode = code || 1; return; }
  fs.mkdirSync('verification', { recursive: true });
  fs.writeFileSync('verification/benchmark.txt', result);
  fs.writeFileSync('lab2/benchmark.csv', result.split('\n').filter(line => line && !line.startsWith('#')).join('\n') + '\n');
});
