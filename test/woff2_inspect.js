'use strict';
/*
 * Dumps the parts of a WOFF2 file the theme font contracts assert against:
 * name-table family, glyph count, variation axes, italic angle and cmap.
 *
 * WOFF2 keeps its table directory uncompressed and concatenates the table data into a
 * single brotli stream, so a table is found by summing the in-stream lengths of the
 * tables ahead of it. Dart has no brotli decoder; node does, and the theme suites
 * already treat it as an optional tool (`_requireNodeInCi` turns the skip into a
 * failure in CI).
 *
 * Usage: node woff2_inspect.js <file.woff2>...
 * Emits {"<basename>": {family, subfamily, italicAngle, numGlyphs, weightClass, axes, cmap}}
 * and exits non-zero with a message naming the file if anything fails to parse - a
 * truncated or zero-byte file lands here rather than in a silently empty result.
 */
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

// Table tags 0-62 of the WOFF2 known-table list; index 63 means a 4-byte tag follows.
const KNOWN = ['cmap', 'head', 'hhea', 'hmtx', 'maxp', 'name', 'OS/2', 'post', 'cvt ', 'fpgm', 'glyf', 'loca',
  'prep', 'CFF ', 'VORG', 'EBDT', 'EBLC', 'gasp', 'hdmx', 'kern', 'LTSH', 'PCLT', 'VDMX', 'vhea', 'vmtx', 'BASE',
  'GDEF', 'GPOS', 'GSUB', 'EBSC', 'JSTF', 'MATH', 'CBDT', 'CBLC', 'COLR', 'CPAL', 'SVG ', 'sbix', 'acnt', 'avar',
  'bdat', 'bloc', 'bsln', 'cvar', 'fdsc', 'feat', 'fmtx', 'fvar', 'gvar', 'hsty', 'just', 'lcar', 'mort', 'morx',
  'opbd', 'prop', 'trak', 'Zapf', 'Silf', 'Glat', 'Gloc', 'Feat', 'Sill'];

function base128(buf, at) {
  let value = 0;
  for (let i = 0; i < 5; i++) {
    const byte = buf[at + i];
    if (byte === undefined) throw new Error('truncated UIntBase128');
    value = (value << 7) | (byte & 0x7f);
    if ((byte & 0x80) === 0) return [value >>> 0, at + i + 1];
  }
  throw new Error('bad UIntBase128');
}

/** Decompressed table data plus each table's offset into it. */
function tables(buf) {
  if (buf.length < 48 || buf.toString('latin1', 0, 4) !== 'wOF2') throw new Error('not a WOFF2 file');
  const numTables = buf.readUInt16BE(12);
  let at = 48;
  const dir = [];
  for (let i = 0; i < numTables; i++) {
    const flags = buf[at++];
    let tag;
    if ((flags & 0x3f) === 0x3f) { tag = buf.toString('latin1', at, at + 4); at += 4; }
    else { tag = KNOWN[flags & 0x3f]; }
    let length;
    [length, at] = base128(buf, at);
    // A transformed table stores its in-stream size in a second UIntBase128. glyf/loca
    // invert the convention: version 3 is the null transform, anything else transforms.
    const version = (flags >> 6) & 0x3;
    const transformed = (tag === 'glyf' || tag === 'loca') ? version !== 3 : version !== 0;
    if (transformed) [length, at] = base128(buf, at);
    dir.push({ tag, length });
  }
  // Bound the stream by the header's own totalCompressedSize rather than by end-of-file, so
  // trailing bytes appended to pad a file past a size floor are ignored here exactly as a
  // browser ignores them - the padding must not be what makes a stub fail.
  const compressed = buf.readUInt32BE(20);
  const data = zlib.brotliDecompressSync(buf.subarray(at, compressed > 0 ? at + compressed : undefined));
  const at_ = {};
  let offset = 0;
  for (const entry of dir) {
    if (!(entry.tag in at_)) at_[entry.tag] = offset;
    offset += entry.length;
  }
  if (offset > data.length) throw new Error(`table directory overruns the brotli stream (${offset} > ${data.length})`);
  return { data, offsets: at_ };
}

/** Name-table string for [nameId], preferring the Windows UTF-16BE record. */
function name(data, base, nameId) {
  const count = data.readUInt16BE(base + 2);
  const strings = base + data.readUInt16BE(base + 4);
  let best = null;
  for (let i = 0; i < count; i++) {
    const rec = base + 6 + i * 12;
    if (data.readUInt16BE(rec + 6) !== nameId) continue;
    const platform = data.readUInt16BE(rec);
    const length = data.readUInt16BE(rec + 8);
    const at = strings + data.readUInt16BE(rec + 10);
    const value = platform === 3
      ? data.subarray(at, at + length).swap16().toString('utf16le')
      : data.toString('latin1', at, at + length);
    if (platform === 3) return value;
    best = best ?? value;
  }
  return best;
}

/** Every codepoint the font maps, from the best available cmap subtable. */
function cmap(data, base) {
  const numTables = data.readUInt16BE(base + 2);
  let best = null;
  for (let i = 0; i < numTables; i++) {
    const rec = base + 4 + i * 8;
    const platform = data.readUInt16BE(rec);
    const encoding = data.readUInt16BE(rec + 2);
    const at = base + data.readUInt32BE(rec + 4);
    const format = data.readUInt16BE(at);
    // Same preference order as fontTools' getBestCmap: full-repertoire subtables first.
    const rank = (platform === 3 && encoding === 10) || (platform === 0 && format === 12) ? 2
      : (platform === 3 && encoding === 1) || platform === 0 ? 1 : 0;
    if (rank === 0 || (best && best.rank >= rank)) continue;
    best = { rank, at, format };
  }
  if (!best) throw new Error('no unicode cmap subtable');
  const out = new Set();
  if (best.format === 4) {
    const segX2 = data.readUInt16BE(best.at + 6);
    const ends = best.at + 14;
    const starts = ends + segX2 + 2;
    const deltas = starts + segX2;
    const rangeOffsets = deltas + segX2;
    for (let s = 0; s < segX2; s += 2) {
      const end = data.readUInt16BE(ends + s);
      const start = data.readUInt16BE(starts + s);
      const delta = data.readInt16BE(deltas + s);
      const rangeOffset = data.readUInt16BE(rangeOffsets + s);
      for (let cp = start; cp <= end && cp !== 0xffff; cp++) {
        let gid;
        if (rangeOffset === 0) gid = (cp + delta) & 0xffff;
        else {
          gid = data.readUInt16BE(rangeOffsets + s + rangeOffset + (cp - start) * 2);
          if (gid !== 0) gid = (gid + delta) & 0xffff;
        }
        if (gid !== 0) out.add(cp);
      }
    }
  } else if (best.format === 12) {
    const groups = data.readUInt32BE(best.at + 12);
    for (let g = 0; g < groups; g++) {
      const rec = best.at + 16 + g * 12;
      const start = data.readUInt32BE(rec);
      const end = data.readUInt32BE(rec + 4);
      for (let cp = start; cp <= end; cp++) out.add(cp);
    }
  } else {
    throw new Error(`unsupported cmap format ${best.format}`);
  }
  return [...out].sort((a, b) => a - b);
}

function inspect(file) {
  const { data, offsets } = tables(fs.readFileSync(file));
  for (const required of ['cmap', 'head', 'maxp', 'name', 'OS/2', 'post']) {
    if (!(required in offsets)) throw new Error(`no ${required} table`);
  }
  const axes = {};
  if ('fvar' in offsets) {
    const base = offsets.fvar;
    const axisOffset = data.readUInt16BE(base + 4);
    const axisCount = data.readUInt16BE(base + 8);
    const axisSize = data.readUInt16BE(base + 10);
    for (let i = 0; i < axisCount; i++) {
      const a = base + axisOffset + i * axisSize;
      axes[data.toString('latin1', a, a + 4)] = [data.readInt32BE(a + 4) / 65536, data.readInt32BE(a + 12) / 65536];
    }
  }
  return {
    // Name ID 16 is the typographic family; a face named for a named instance (Bricolage's
    // "Bricolage Grotesque 96pt ExtraBold") only carries the real family there.
    family: name(data, offsets.name, 16) ?? name(data, offsets.name, 1),
    subfamily: name(data, offsets.name, 2),
    italicAngle: data.readInt32BE(offsets.post + 4) / 65536,
    numGlyphs: data.readUInt16BE(offsets.maxp + 4),
    weightClass: data.readUInt16BE(offsets['OS/2'] + 4),
    axes,
    cmap: cmap(data, offsets.cmap),
  };
}

const result = {};
for (const file of process.argv.slice(2)) {
  try {
    result[path.basename(file)] = inspect(file);
  } catch (error) {
    process.stderr.write(`${path.basename(file)}: ${error.message}\n`);
    process.exit(1);
  }
}
process.stdout.write(JSON.stringify(result));
