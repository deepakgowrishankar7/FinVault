const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

async function run() {
  const svgPath = path.join(__dirname, 'icon.svg');
  const svgBuffer = fs.readFileSync(svgPath);

  // 1. Generate Root PWA Icons
  await sharp(svgBuffer).resize(192, 192).png().toFile(path.join(__dirname, 'icon-192.png'));
  console.log('Generated icon-192.png');

  await sharp(svgBuffer).resize(512, 512).png().toFile(path.join(__dirname, 'icon-512.png'));
  console.log('Generated icon-512.png');

  // 2. Android Mipmap Sizes (Standard & Round)
  const mipmaps = [
    { dir: 'mipmap-mdpi', size: 48, fgSize: 108 },
    { dir: 'mipmap-hdpi', size: 72, fgSize: 162 },
    { dir: 'mipmap-xhdpi', size: 96, fgSize: 216 },
    { dir: 'mipmap-xxhdpi', size: 144, fgSize: 324 },
    { dir: 'mipmap-xxxhdpi', size: 192, fgSize: 432 }
  ];

  const resDir = path.join(__dirname, 'android', 'app', 'src', 'main', 'res');

  for (const m of mipmaps) {
    const targetDir = path.join(resDir, m.dir);
    if (!fs.existsSync(targetDir)) continue;

    // Standard Launcher Icon
    await sharp(svgBuffer).resize(m.size, m.size).png().toFile(path.join(targetDir, 'ic_launcher.png'));
    // Round Launcher Icon
    await sharp(svgBuffer).resize(m.size, m.size).png().toFile(path.join(targetDir, 'ic_launcher_round.png'));
    // Adaptive Foreground Icon
    await sharp(svgBuffer).resize(m.fgSize, m.fgSize).png().toFile(path.join(targetDir, 'ic_launcher_foreground.png'));

    console.log(`Updated Android ${m.dir} icons (${m.size}px)`);
  }

  // 3. Update Adaptive Icon Background color to Obsidian Black
  const bgXmlPath = path.join(resDir, 'values', 'ic_launcher_background.xml');
  if (fs.existsSync(bgXmlPath)) {
    const bgXml = `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0B0E14</color>
</resources>\n`;
    fs.writeFileSync(bgXmlPath, bgXml, 'utf8');
    console.log('Updated ic_launcher_background.xml to #0B0E14');
  }

  console.log('All icons generated successfully!');
}

run().catch(console.error);
