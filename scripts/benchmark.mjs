import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
process.chdir(path.resolve(import.meta.dirname,'..'));
const executable=process.platform==='win32'?'.build/lab2.exe':'.build/lab2-run';
const child=spawn(executable,['benchmark','384','4','+RTS','-N4','-RTS'],{stdio:['ignore','pipe','inherit']});
let output='';
child.stdout.on('data',chunk=>{output+=chunk.toString();process.stdout.write(chunk);});
child.on('error',error=>{throw error;});
child.on('exit',code=>{
  if(code!==0){process.exitCode=code||1;return;}
  fs.writeFileSync('verification/benchmark.txt',output);
  fs.writeFileSync('lab2/benchmark.csv',output.split('\n').filter(line=>line&&!line.startsWith('#')).join('\n')+'\n');
});
