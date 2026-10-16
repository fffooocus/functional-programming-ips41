import fs from 'node:fs';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import net from 'node:net';

const root = path.resolve(import.meta.dirname, '..');
process.chdir(root);
const portable = path.join(root, '.tools', 'mysql-8.4.6-winx64');
const shortFile = path.join(root, '.tools', 'short-path.txt');
const nativeRoot = fs.existsSync(shortFile) ? fs.readFileSync(shortFile, 'utf8').trim() : root;
const mysqlRoot = path.join(nativeRoot, '.tools', 'mysql-8.4.6-winx64');
const mysql = path.join(mysqlRoot, 'bin', 'mysql.exe');
const command = process.argv[2] || 'demo';
const env = { ...process.env, MYSQL_BIN: mysql, MYSQL_HOST: '127.0.0.1', MYSQL_PORT: '3307', MYSQL_USER: 'root' };

function execute(file, args, options = {}) {
  const result = spawnSync(file, args, { cwd: nativeRoot, env, stdio: 'inherit', ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Command exited with ${result.status}`);
  return result;
}
function connected() {
  return new Promise(resolve => {
    const socket = net.connect({ host: '127.0.0.1', port: 3307 });
    socket.setTimeout(500);
    socket.once('connect', () => { socket.destroy(); resolve(true); });
    socket.once('error', () => resolve(false));
    socket.once('timeout', () => { socket.destroy(); resolve(false); });
  });
}
async function start() {
  if (!fs.existsSync(portable)) throw new Error('Portable MySQL is missing. See README.md for Docker or Windows setup.');
  if (!await connected()) {
    const data = path.join(nativeRoot, '.tools', 'mysql-data');
    if (!fs.existsSync(path.join(data, 'mysql'))) {
      execute(path.join(mysqlRoot, 'bin', 'mysqld.exe'), ['--no-defaults', '--initialize-insecure', `--basedir=${mysqlRoot}`, `--datadir=${data}`, '--console']);
    }
    const log = fs.openSync(path.join(root, '.tools', 'mysql-local.log'), 'a');
    const child = spawn(path.join(mysqlRoot, 'bin', 'mysqld.exe'),
      ['--no-defaults', '--standalone', `--basedir=${mysqlRoot}`, `--datadir=${data}`,
        '--port=3307', '--bind-address=127.0.0.1', '--mysqlx=OFF', '--console'],
      { cwd: nativeRoot, detached: true, windowsHide: true, stdio: ['ignore', log, log] });
    child.unref();
    fs.closeSync(log);
    for (let attempt = 0; attempt < 60 && !await connected(); attempt++) await new Promise(resolve => setTimeout(resolve, 500));
    if (!await connected()) throw new Error('MySQL did not start; see .tools/mysql-local.log');
  }
  for (const file of ['01-schema.sql', '02-seed.sql']) {
    execute(mysql, ['--no-defaults', '--protocol=TCP', '-h127.0.0.1', '-P3307', '-uroot', '--default-character-set=utf8mb4'],
      { input: fs.readFileSync(path.join(root, 'lab1/sql', file)), stdio: ['pipe', 'inherit', 'inherit'] });
  }
}

if (command === 'stop') {
  execute(path.join(mysqlRoot, 'bin', 'mysqladmin.exe'), ['--no-defaults', '--protocol=TCP', '-h127.0.0.1', '-P3307', '-uroot', 'shutdown']);
} else {
  await start();
  if (command === 'start') console.log('MySQL ready at 127.0.0.1:3307.');
  else if (command === 'verify') execute(process.execPath, ['scripts/verify.mjs']);
  else if (command === 'lab1') execute(path.join(root, '.build', 'lab1.exe'), process.argv.slice(3));
  else if (command === 'demo') {
    execute(path.join(root, '.build', 'lab1.exe'), ['list']);
    execute(path.join(root, '.build', 'lab1.exe'), ['stats']);
    execute(path.join(root, '.build', 'lab3.exe'), ['lab3/examples/textbook.txt']);
    console.log('Lab 2: node scripts/benchmark.mjs');
  } else throw new Error('Usage: node scripts/local.mjs start|stop|demo|verify|lab1 [ARGS...]');
}
