// Only public keys enrolled by this package are managed here. Never infer
// ownership from a user-supplied SSH comment or enumerate unrelated login keys.
import { createHash, randomBytes } from 'node:crypto';
import { mkdirSync, readFileSync, readdirSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { commentOf, editAuthorizedKeys } from '../src/authorized-keys.js';
import { parseDeviceKeyLine } from '../src/device-key.js';

const directory = stateDir => join(stateDir, 'nix-devices');
const recordPath = (stateDir, fingerprint) => join(directory(stateDir), `${createHash('sha256').update(fingerprint).digest('hex')}.json`);

// SSH options may contain quoted spaces (for example command="some command").
// Tokenize those options before locating the actual key, so a comment or forced
// command containing a different public key can never select that other key.
function keyIdentity(line) {
  if (!line.trim() || line.trimStart().startsWith('#')) return '';
  const words = [];
  let word = '', quoted = false, escaped = false;
  for (const character of line.trim()) {
    if (escaped) { word += character; escaped = false; }
    else if (character === '\\') { escaped = true; word += character; }
    else if (character === '"') { quoted = !quoted; word += character; }
    else if (/\s/.test(character) && !quoted) {
      if (word) { words.push(word); word = ''; }
    } else word += character;
  }
  if (word) words.push(word);
  const position = words[0] === 'ssh-ed25519' ? 0 : 1;
  return words[position] === 'ssh-ed25519' ? `${words[position]} ${words[position + 1]}` : '';
}

export function writeJson(path, value) {
  const temporary = `${path}.${process.pid}.${randomBytes(6).toString('hex')}.tmp`;
  try {
    writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600, flag: 'wx' });
    renameSync(temporary, path);
  } finally {
    rmSync(temporary, { force: true });
  }
}

// Called inside upstream's authorized_keys lock, before the same atomic edit
// commits the device key. A failed commit can leave an inactive inventory row,
// which listDevices explicitly distinguishes from an authorized device.
export function rememberDevice({ stateDir, line, fingerprint }) {
  const parsed = parseDeviceKeyLine(line);
  if (parsed.fingerprint !== fingerprint) throw new Error('Device fingerprint mismatch');
  mkdirSync(directory(stateDir), { recursive: true, mode: 0o700 });
  const path = recordPath(stateDir, fingerprint);
  let previous;
  try { previous = JSON.parse(readFileSync(path, 'utf8')); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  const now = new Date().toISOString();
  writeJson(path, {
    version: 1, fingerprint, line: parsed.line,
    label: previous?.label ?? (commentOf(parsed.line) || fingerprint),
    createdAt: previous?.createdAt ?? now, pairedAt: now,
  });
}

export function listDevices(stateDir, home) {
  let files;
  try { files = readdirSync(directory(stateDir)).filter(name => name.endsWith('.json')); }
  catch (error) { if (error.code === 'ENOENT') return []; throw error; }
  let authorized = '';
  try { authorized = readFileSync(join(home, '.ssh', 'authorized_keys'), 'utf8'); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  const blobs = new Set(authorized.split('\n').map(keyIdentity));
  return files.map(name => {
    const record = JSON.parse(readFileSync(join(directory(stateDir), name), 'utf8'));
    const parsed = parseDeviceKeyLine(record.line);
    if (record.version !== 1 || parsed.fingerprint !== record.fingerprint ||
        recordPath(stateDir, record.fingerprint) !== join(directory(stateDir), name)) {
      throw new Error(`Invalid device record: ${name}`);
    }
    return { ...record, active: blobs.has(keyIdentity(parsed.line)) };
  }).sort((a, b) => a.createdAt.localeCompare(b.createdAt));
}

export async function changeDevice({ stateDir, home, identity, label }) {
  let changed;
  await editAuthorizedKeys(home, lines => {
    const matches = listDevices(stateDir, home).filter(d => d.fingerprint === identity || d.label === identity);
    if (matches.length !== 1) throw new Error('Use a unique device label or its full SHA256 fingerprint');
    changed = matches[0];
    if (label !== undefined) {
      if (!label.trim() || /[\x00-\x1f\x7f]/.test(label)) throw new Error('Invalid device label');
      const { active, ...record } = changed;
      writeJson(recordPath(stateDir, record.fingerprint), { ...record, label });
      return null;
    }
    return lines.filter(line => keyIdentity(line) !== keyIdentity(changed.line));
  });
  // Keep the inventory if committing authorized_keys fails, so revocation can
  // be retried without losing the exact key identity.
  if (label === undefined) rmSync(recordPath(stateDir, changed.fingerprint));
  return changed;
}
