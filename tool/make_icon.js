// GLOWDEEP uygulama ikonu — tamamen prosedürel PNG üretimi (asset yok, telif yok)
// Node.js ile çalıştır: node tool/make_icon.js
const zlib = require('zlib');
const fs = require('fs');

const W = 1024, H = 1024;

// --- CRC32 ---
const crcTable = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
const crc32 = (buf) => {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};

const chunk = (type, data) => {
  const b = Buffer.alloc(8 + data.length + 4);
  b.writeUInt32BE(data.length, 0);
  b.write(type, 4);
  data.copy(b, 8);
  b.writeUInt32BE(crc32(Buffer.concat([Buffer.from(type), data])), 8 + data.length);
  return b;
};

// --- piksel üretimi ---
const cx = W / 2, cy = H / 2;
const px = Buffer.alloc(W * H * 4);

const lerp = (a, b, t) => a + (b - a) * t;
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));

// renkler
const BG_TOP = [6, 10, 26];
const BG_BOT = [12, 8, 34];
const GOLD = [255, 200, 80];
const CORE = [255, 248, 224];
const RING = [255, 170, 60];

for (let y = 0; y < H; y++) {
  for (let x = 0; x < W; x++) {
    const i = (y * W + x) * 4;
    // arka plan degrade + ince vinyet
    const ty = y / H;
    let r = lerp(BG_TOP[0], BG_BOT[0], ty);
    let g = lerp(BG_TOP[1], BG_BOT[1], ty);
    let b = lerp(BG_TOP[2], BG_BOT[2], ty);

    const dEdge = Math.min(x, y, W - x, H - y) / (W * 0.5);
    const vig = 0.55 + 0.45 * clamp(dEdge * 1.6, 0, 1);
    r *= vig; g *= vig; b *= vig;

    // yörünge halkası (ince elips)
    const dOrb = Math.hypot(x - cx, (y - cy) * 1.35);
    const ringW = 14;
    const ringD = Math.abs(dOrb - 330);
    if (ringD < ringW) {
      const k = 1 - ringD / ringW;
      const fade = clamp((330 - Math.hypot(x - cx, y - cy) / 400), 0.15, 1); // içeride daha görünür
      r = lerp(r, RING[0], k * 0.5 * fade);
      g = lerp(g, RING[1], k * 0.5 * fade);
      b = lerp(b, RING[2], k * 0.5 * fade);
    }

    // ana ışık küresi
    const d = Math.hypot(x - cx, y - cy);
    const glowR = 380, coreR = 150;
    if (d < glowR) {
      const t = 1 - d / glowR;
      const gk = Math.pow(t, 2.2);
      r = lerp(r, GOLD[0], gk * 0.85);
      g = lerp(g, GOLD[1], gk * 0.85);
      b = lerp(b, GOLD[2], gk * 0.85);
    }
    if (d < coreR) {
      const t = 1 - d / coreR;
      const ck = Math.pow(t, 1.1);
      // çekirdek: beyaza doğru
      r = lerp(r, CORE[0], ck);
      g = lerp(g, CORE[1], ck);
      b = lerp(b, CORE[2], ck);
      // alt-sol parlama noktası
      const hl = Math.hypot(x - (cx - 45), y - (cy - 50));
      if (hl < 55) {
        const hk = 1 - hl / 55;
        r = lerp(r, 255, hk * 0.9); g = lerp(g, 255, hk * 0.9); b = lerp(b, 255, hk * 0.9);
      }
    }

    // minik parlayan tozlar (sabit "yıldız" noktaları)
    const sx = (x * 2654435761 + y * 40503) % 997;
    if (sx === 0 && d > coreR + 60) {
      const dd = Math.hypot(x - cx, y - cy);
      const fade = clamp(1 - dd / 480, 0, 1);
      r += 200 * fade; g += 190 * fade; b += 140 * fade;
    }

    px[i] = clamp(r, 0, 255);
    px[i + 1] = clamp(g, 0, 255);
    px[i + 2] = clamp(b, 0, 255);
    px[i + 3] = 255;
  }
}

// --- PNG kodlama (filter: none) ---
const raw = Buffer.alloc(H * (1 + W * 4));
for (let y = 0; y < H; y++) {
  raw[y * (1 + W * 4)] = 0;
  px.copy(raw, y * (1 + W * 4) + 1, y * W * 4, (y + 1) * W * 4);
}

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4);
ihdr[8] = 8; ihdr[9] = 6; // 8bit RGBA

const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr),
  chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0)),
]);

fs.writeFileSync('assets/icon.png', png);
console.log('icon.png yazıldı:', png.length, 'bayt');
