import { readdir,readFile } from 'node:fs/promises';
import { join } from 'node:path';
const forbidden=[/-----BEGIN (?:RSA )?PRIVATE KEY-----/,/GOOGLE_APPLICATION_CREDENTIALS/,/DATABASE_URL/,/firebase-admin(?:\/|sdk)/,/"private_key"\s*:/];
let checked=0;async function scan(directory){for(const entry of await readdir(directory,{withFileTypes:true})){const target=join(directory,entry.name);if(entry.isDirectory())await scan(target);else if(/\.(?:js|json|map)$/.test(entry.name)){const content=await readFile(target,'utf8');if(forbidden.some(pattern=>pattern.test(content)))throw new Error('Server-only credential marker found in browser build.');checked++;}}}
await scan('.next/static');console.log('Browser bundle audit passed: '+checked+' files; no server credential markers.');
