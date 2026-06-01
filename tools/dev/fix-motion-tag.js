const fs = require('fs');
const p = require('path').join(__dirname, '..', 'FloatingToolbarStrip.html');
let h = fs.readFileSync(p, 'utf8');
const bad = '</motion>';
const good = '</div>';
const n = h.split(bad).length - 1;
if (!n) {
  console.log('no </motion> tags');
  process.exit(0);
}
h = h.split(bad).join(good);
fs.writeFileSync(p, h);
console.log('replaced', n, 'tags');
