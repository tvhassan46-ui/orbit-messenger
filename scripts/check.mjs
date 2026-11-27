// Syntax-check inline scripts and flag duplicate IDs in static HTML.
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
let failed=false;
for(const [i,m] of [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].entries()){
 const code=m[1]; if(!code.trim())continue;
 try{new vm.Script(code,{filename:'index.html script '+(i+1)});}catch(e){failed=true;console.error(e.stack.split('\n').slice(0,5).join('\n'));}
}
const ids=[...html.matchAll(/\bid="([\w-]+)"/g)].map(m=>m[1]);
const duplicates=ids.filter((id,i)=>ids.indexOf(id)!==i);
if(duplicates.length){failed=true;console.error('Duplicate static IDs:',[...new Set(duplicates)].join(', '));}
if(failed)process.exit(1);
console.log('Inline JavaScript parses; no duplicate static IDs.');
