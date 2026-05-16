const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, '..', 'FloatingToolbarStrip.html');
const html = fs.readFileSync(file, 'utf8');
const si = html.indexOf('<script');
const head = html.slice(0, si);
const tail = html.slice(si);

const rules = [
  [/ftbBootFallback" class="ftb-boot-fb" hidden>[^<]*<\/>/g, 'ftbBootFallback" class="ftb-boot-fb" hidden>牛</span>'],
  [/(<div id="empty">[\s\S]*?)<\/>/g, '$1</div>'],
  [/(<div class="cli-title" id="cliTitle">[\s\S]*?)<\/>/g, '$1</div>'],
  [/(<button class="btn3" id="attachFolderBtn" type="button">[\s\S]*?)<\/>/g, '$1</button>'],
  [/(<button class="btn1" id="send" type="button">[\s\S]*?)<\/>/g, '$1</button>'],
  [/(<label for="providerDdBtn">[\s\S]*?)<\/>/g, '$1</label>'],
  [/(<span class="dd-chev" aria-hidden="true">[\s\S]*?)<\/>/g, '$1</span>'],
  [/(<label for="ttydShellCommand">[\s\S]*?)<\/>/g, '$1</label>'],
  [/(<div class="hint mini">[\s\S]*?)<\/>/g, '$1</div>'],
  [/(<div class="hint mini" id="openclawSessionHint">[\s\S]*?)<\/>/g, '$1</div>'],
  [/(<button type="button" class="btn3" id="promptTplApply">[\s\S]*?)<\/>/g, '$1</button>'],
  [/(<button type="button" class="btn3" id="promptImportBtn">[\s\S]*?)<\/>/g, '$1</button>'],
  [/(<div class="hint">[\s\S]*?)<\/>/g, '$1</div>'],
  [/(<div class="nst">[\s\S]*?)<\/>/g, '$1</div>'],
];

let fixed = head;
for (const [re, rep] of rules) {
  fixed = fixed.replace(re, rep);
}

const left = (fixed.match(/<\/>/g) || []).length;
if (left) {
  console.error('still have', left, 'broken </> tags');
  const idx = fixed.indexOf('</>');
  console.error(fixed.slice(Math.max(0, idx - 80), idx + 40));
  process.exit(1);
}

fs.writeFileSync(file, fixed + tail, 'utf8');
console.log('fixed HTML closing tags OK');
