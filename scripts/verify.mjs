import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '..');
process.chdir(root);
const exe = lab => path.join(root, '.build', process.platform === 'win32' ? `${lab}.exe` : `${lab}-run`);
fs.mkdirSync('verification', { recursive: true });
let transcript = '';
function run(lab, args, fail = false) {
  const result = spawnSync(exe(lab), args, { encoding: 'utf8', env: process.env });
  if (result.error) throw result.error;
  if (fail) assert.notEqual(result.status, 0, 'Expected failure');
  else assert.equal(result.status, 0, result.stderr);
  transcript += `$ ${lab} ${args.join(' ')}\n${result.stdout}${result.stderr}\n`;
  return result.stdout;
}
function save(lab) { fs.writeFileSync(`verification/${lab}.txt`, transcript.trimEnd()+'\n'); transcript=''; }
fs.writeFileSync('verification/environment.json', JSON.stringify({ timestamp:new Date().toISOString(), variant:3,
  platform:os.platform(), architecture:os.arch(), cpu:os.cpus()[0].model.trim(), logical_processors:os.cpus().length,
  ghc:'9.6.7', compiler_flags:'-O2 -Wall -threaded -rtsopts' },null,2)+'\n');
const analysis = run('lab3', ['lab3/examples/textbook.txt','--output','lab3/results.txt']);
assert.match(analysis,/якого немає в інших: функціональна/);
assert.match(analysis,/функціональна, програмування/);
save('lab3');
const result1 = run('lab2',['solve','1','lab2/examples/system.txt','+RTS','-N1','-RTS']);
const result4 = run('lab2',['solve','4','lab2/examples/system.txt','--output','lab2/results.txt','+RTS','-N4','-RTS']);
assert.equal(result1,result4);
for (const [i,expected] of [2,3,-1].entries()) {
  const value=Number(result4.match(new RegExp(`x${i+1} = (\\S+)`))[1]);
  assert.ok(Math.abs(value-expected)<1e-9);
}
run('lab2',['solve','4','lab2/examples/pivot.txt','+RTS','-N4','-RTS']);
run('lab2',['solve','0','lab2/examples/system.txt'],true);
const temporary=fs.mkdtempSync(path.join(root,'.build','gaussian-'));
const singular=path.join(temporary,'singular.txt');
fs.writeFileSync(singular,'2\n1 2 3\n2 4 6\n');
run('lab2',['solve','2',singular],true);
transcript=transcript.replaceAll(temporary,'<temporary-directory>');
save('lab2');
if (process.env.MYSQL_BIN) {
  assert.match(run('lab1',['list']),/GHC \| 9.6.7/);
  run('lab1',['catalog']); run('lab1',['search','GHC']); run('lab1',['details','1']); run('lab1',['stats']);
  const title="Перевірка ' SQL; --";
  const id=run('lab1',['add',title,'1.0','Тест\tтабуляції\nта нового рядка','1','1','2026-10-01','-']).match(/Created resource (\d+)/)[1];
  assert.match(run('lab1',['search',title]),/Перевірка/);
  assert.equal(run('lab1',['search',"' OR 1=1 --"]).trim(),'');
  run('lab1',['update',id,'Оновлена програма','2.0','Оновлена анотація','2','2','2026-10-01','2027-06-30']);
  assert.match(run('lab1',['search','Оновлена програма']),/Оновлена програма \| 2.0/);
  run('lab1',['link-author',id,'3']); run('lab1',['link-purpose',id,'2']);
  run('lab1',['url-add',id,'https://example.org/distribution.zip']);
  run('lab1',['edit','authors','3','name','Левківський Євгеній Сергійович']);
  run('lab1',['edit','authors;DROP TABLE users','3','name','bad'],true);
  run('lab1',['grant',id,'1']); run('lab1',['visit',id,'1','90']);
  assert.match(run('lab1',['stats']),/Оновлена програма \| 1 \| 1 \| 90/);
  run('lab1',['add','Bad','1.0','Bad','1','1','2026-02-30','-'],true);
  run('lab1',['add','Bad FK','1.0','Bad','999999','1','2026-10-01','-'],true);
  run('lab1',['delete',id]);
  assert.equal(run('lab1',['search','Оновлена програма']).trim(),'');
  save('lab1');
} else console.log('MySQL integration skipped: set MYSQL_BIN.');
console.log('Variant 3 CLI integration checks passed.');
