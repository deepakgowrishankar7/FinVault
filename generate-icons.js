const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

async function run() {
  const srcPath = path.join(__dirname, 'logo-source.png');
  const srcBuffer = fs.readFileSync(srcPath);

  // 1. Generate Root PWA Icons
  await sharp(srcBuffer).resize(192, 192).png().toFile(path.join(__dirname, 'icon-192.png'));
  console.log('Generated icon-192.png');

  await sharp(srcBuffer).resize(512, 512).png().toFile(path.join(__dirname, 'icon-512.png'));
  console.log('Generated icon-512.png');

  // 2. Generate icon.svg wrapping the 512px icon
  const b64 = (await sharp(srcBuffer).resize(512, 512).png().toBuffer()).toString('base64');
  const svgContent = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="100%" height="100%">
  <image href="data:image/png;base64,${b64}" width="512" height="512" />
</svg>\n`;
  fs.writeFileSync(path.join(__dirname, 'icon.svg'), svgContent, 'utf8');
  console.log('Generated icon.svg from high-res logo');

  // 3. Android Mipmap Sizes (Standard & Round)
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
    await sharp(srcBuffer).resize(m.size, m.size).png().toFile(path.join(targetDir, 'ic_launcher.png'));
    // Round Launcher Icon
    await sharp(srcBuffer).resize(m.size, m.size).png().toFile(path.join(targetDir, 'ic_launcher_round.png'));
    // Adaptive Foreground Icon
    await sharp(srcBuffer).resize(m.fgSize, m.fgSize).png().toFile(path.join(targetDir, 'ic_launcher_foreground.png'));

    console.log(`Updated Android ${m.dir} icons (${m.size}px)`);
  }

  // 4. Update Adaptive Icon Background color to Obsidian Black
  const bgXmlPath = path.join(resDir, 'values', 'ic_launcher_background.xml');
  if (fs.existsSync(bgXmlPath)) {
    const bgXml = `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#06429A</color>
</resources>\n`;
    fs.writeFileSync(bgXmlPath, bgXml, 'utf8');
    console.log('Updated ic_launcher_background.xml to #06429A');
  }

  console.log('All icons generated successfully!');
}

run().catch(console.error);
