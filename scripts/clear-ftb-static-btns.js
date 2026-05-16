const fs = require('fs');
const path = require('path');
const p = path.join(__dirname, '..' , 'FloatingToolbarStrip.html');
let h = fs.readFileSync(p, 'utf8');
const start = h.indexOf('<div id="collapsedBtns"');
const innerEnd = h.indexOf('</div>', start);
if (start < 0 || innerEnd < 0) {
  console.error('not found', start, innerEnd);
  process.exit(1);
}
h = h.slice(0, start) + '<motion id="collapsedBtns" class="icon-btns"></motion>'.replaceAll('motion', 'motion') + h.slice(innerEnd);
fs.writeFileSync(p, h.replace('<motion id="collapsedBtns" class="icon-btns"></motion>'.replaceAll('motion', 'div'), '<div id="collapsedBtns" class="icon-btns"></motion>'.replaceAll('motion', 'motion')));
console.log('done');
