const fs = require('fs');
const path = require('path');
const acorn = require('acorn');

const file = path.join(__dirname, '..', 'FloatingToolbarStrip.html');
const html = fs.readFileSync(file, 'utf8');
const m = html.match(/<script[^>]*>([\s\S]*)<\/script>\s*<\/body>/i);
if (!m) {
  console.error('no script');
  process.exit(1);
}

let src = m[1];
const scriptStart = html.indexOf(m[1]);
let total = 0;

for (let pass = 0; pass < 200; pass++) {
  try {
    acorn.parse(src, { ecmaVersion: 2020, sourceType: 'script' });
    console.log('parse OK after', pass, 'passes,', total, 'fixes');
    break;
  } catch (e) {
    const lines = src.split(/\n/);
    const ln = e.loc.line - 1;
    let line = lines[ln];
    const before = line;

    if (/\?;\s*$/.test(line)) line = line.replace(/\?;\s*$/, "';");
    else if (/\?,\s*$/.test(line)) line = line.replace(/\?,\s*$/, "',");
    else if (/\?'\s*\+/.test(line)) line = line.replace(/\?'/, "'");
    else if (/\?\s*:\s*'/.test(line) && (line.match(/'/g) || []).length % 2 === 1) {
      line = line.replace(/\?\s*:\s*'/, "': '");
    } else if (/\?,\s*'/.test(line)) line = line.replace(/\?,\s*'/, "', '");
    else {
      console.error('cannot fix line', e.loc.line, ':', line.trim().slice(0, 120));
      process.exit(1);
    }

    if (line === before) {
      console.error('no change on line', e.loc.line);
      process.exit(1);
    }
    lines[ln] = line;
    src = lines.join('\n');
    total++;
  }
}

const newHtml = html.slice(0, scriptStart) + src + html.slice(scriptStart + m[1].length);
fs.writeFileSync(file, newHtml, 'utf8');
console.log('wrote', file, 'total fixes', total);
