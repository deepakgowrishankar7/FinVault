const fs = require('fs');
const path = require('path');

const outDir = path.join(__dirname, 'www');
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

const files = [
  'index.html',
  'styles.css',
  'qrcode.min.js',
  'app.js',
  'manifest.json',
  'sw.js',
  'icon.svg',
  'icon-192.png',
  'icon-512.png',
  'screenshot1.png'
];

files.forEach(file => {
  const src = path.join(__dirname, file);
  const dest = path.join(outDir, file);
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, dest);
    console.log(`Copied ${file} -> www/${file}`);
  }
});

console.log('Build complete! www/ ready for Capacitor.');
