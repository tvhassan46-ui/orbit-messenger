// Fails if any script on the page has a syntax error, or if code looks up an element that does not exist.
// A single syntax error silently disables every button, so run this before each deploy.
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
let failed = false;
[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].forEach(([, code], i) => {
  try { new vm.Script(code, { filename: `index.html inline script ${i + 1}` }); }
  catch (e) { failed = true; console.error(e.stack.split('\n').slice(0, 5).join('\n')); }
});
// Only elements written above the main script exist while it runs.
const markup = html.slice(0, html.indexOf('<script>'));
// Ids inside script strings are elements the script creates itself.
const generated = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]).join('\n');
const ids = new Set([...(markup + generated).matchAll(/\bid="([\w-]+)"/g)].map((m) => m[1]));
for (const [, id] of html.matchAll(/\$\('([\w-]+)'\)/g)) {
  if (!ids.has(id)) { failed = true; console.error(`Element id missing, or declared after the script: ${id}`); }
}
if (failed) process.exit(1);
console.log('Page scripts parse and all element ids exist.');
