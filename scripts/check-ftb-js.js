const fs = require('fs');
const path = require('path');
const acorn = require('acorn');
const html = fs.readFileSync(path.join(__dirname, '..', 'FloatingToolbarStrip.html'), 'utf8');
const m = html.match(/<script[^>]*>([\s\S]*)<\/script>\s*<\/body>/i);
if (!m) {
  console.error('no script block');
  process.exit(1);
}
const src = m[1];
const offset = html.indexOf(m[1]);
try {
  acorn.parse(src, { ecmaVersion: 2020, sourceType: 'script', locations: true });
  console.log('acorn parse OK, len', src.length);
} catch (e) {
  console.log('acorn FAIL:', e.message);
  if (e.loc) {
    const line = e.loc.line;
    const col = e.loc.column;
    const lines = src.split(/\n/);
    console.log('at script line', line, 'col', col, '(html ~', line + 527, ')');
    for (let i = Math.max(0, line - 3); i < Math.min(lines.length, line + 2); i++) {
      console.log(String(i + 1).padStart(5), lines[i]);
    }
  }
}
