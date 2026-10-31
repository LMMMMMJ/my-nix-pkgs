import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, lstatSync, mkdirSync, readFileSync } from 'node:fs';
import { createConnection, isIP } from 'node:net';
import { homedir, userInfo } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { changeDevice, listDevices, writeJson } from './device-registry.mjs';
import { readPairingConfig } from '../src/pairing-config.js';

const pluginDirectory = fileURLToPath(new URL('../', import.meta.url));
const digest = value => createHash('sha256').update(value).digest('hex');

export function pairingDefaults(settings, status) {
  const port = settings.sshPort ?? 22;
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid SSH port');
  let addresses = settings.addresses;
  if (addresses === undefined) {
    if (status?.BackendState !== 'Running') throw new Error('Sign in to your own Tailscale instance first');
    addresses = [...(status.Self?.TailscaleIPs ?? []).filter(ip => isIP(ip)), status.Self?.DNSName?.replace(/\.$/, '')].filter(Boolean);
  }
  if (!Array.isArray(addresses) || !addresses.length || addresses.some(a => typeof a !== 'string' || !a || /\s/.test(a))) {
    throw new Error('No valid pairing addresses; check Tailscale or configure addresses');
  }
  return { ssh_port: port, addresses: [...new Set(addresses)] };
}

// A hand-edited pair.json always wins. A small sidecar lets a later invocation
// refresh our own generated defaults when the user's Tailscale identity changes.
export function ensurePairingConfig(directory, defaults) {
  mkdirSync(directory, { recursive: true, mode: 0o700 });
  const path = join(directory, 'pair.json');
  const marker = join(directory, '.nix-pair-defaults.json');
  if (existsSync(path)) {
    let owned = false;
    try {
      owned = lstatSync(path).isFile() && JSON.parse(readFileSync(marker, 'utf8')).sha256 === digest(readFileSync(path, 'utf8'));
    } catch (error) {
      if (error.code !== 'ENOENT' && !(error instanceof SyntaxError)) throw error;
    }
    if (!owned) {
      const parsed = readPairingConfig(directory);
      const problems = [parsed.warning, parsed.addressesWarning, parsed.launcherWarning].filter(Boolean);
      if (problems.length) throw new Error(problems.join(' '));
      return { path, customized: true };
    }
  }
  writeJson(path, defaults);
  writeJson(marker, { version: 1, sha256: digest(readFileSync(path, 'utf8')) });
  return { path, customized: false };
}

function execute(binary, args) {
  try { return execFileSync(binary, args, { encoding: 'utf8', timeout: 20000 }).trim(); }
  catch (error) { throw new Error(`${binary} ${args.join(' ')} failed: ${String(error.stderr ?? error.message).trim()}`); }
}

function tcpBanner(port) {
  return new Promise((resolve, reject) => {
    const socket = createConnection({ host: '127.0.0.1', port });
    socket.setTimeout(3000, () => socket.destroy(new Error('SSH connection timed out')));
    socket.once('data', bytes => {
      socket.destroy();
      if (!bytes.toString().startsWith('SSH-2.0-')) reject(new Error('Port did not answer with an SSH banner'));
      else resolve();
    });
    socket.once('error', reject);
  });
}

const help = `heeler — Nix-managed Herdr companion setup

  heeler setup                      register the packaged plugin and prepare defaults
  heeler pair [--session NAME]       add another device; existing devices stay authorized
  heeler doctor [--session NAME]     check runtime, plugin, Tailscale and local OpenSSH
  heeler devices list [--json]       list device keys enrolled by this package
  heeler devices rename ID NAME      give one fingerprint a readable label
  heeler devices revoke ID           revoke one managed SSH device key

IDs are full SHA256 fingerprints or unique labels. Revocation blocks new SSH
logins; it does not terminate existing SSH sessions or remove APNs registrations.
The QR must be opened from your own Herdr terminal. No server is started here.`;

export async function main(input, injected = {}) {
  const args = [...input];
  if (!args.length || args.includes('--help') || args.includes('-h')) { console.log(help); return; }
  const runtime = injected.runtime ?? JSON.parse(readFileSync(new URL('./runtime.json', import.meta.url), 'utf8'));
  if (args[0] === 'version' || args[0] === '--version') {
    console.log(`heeler ${JSON.parse(readFileSync(join(pluginDirectory, 'package.json'), 'utf8')).version}`); return;
  }
  const home = injected.home ?? homedir();
  const username = injected.username ?? userInfo().username;
  const settingsFile = join(runtime.settingsDirectory, `${username}.json`);
  let settings = {};
  if (existsSync(settingsFile)) settings = JSON.parse(readFileSync(settingsFile, 'utf8'));
  else if (runtime.requireSettings) throw new Error(`No Heeler defaults at ${settingsFile}; ask an administrator to configure this Unix user`);
  const sessionIndex = args.indexOf('--session');
  const prefix = [];
  if (sessionIndex >= 0) {
    const session = args[sessionIndex + 1];
    if (!session || session.startsWith('-')) throw new Error('--session needs a name');
    prefix.push('--session', session); args.splice(sessionIndex, 2);
  }
  const run = injected.execute ?? execute;
  const herdr = argv => run(runtime.herdr, [...prefix, ...argv]);
  const stateDir = injected.stateDir ?? join(process.env.XDG_STATE_HOME ?? join(home, '.local', 'state'), 'herdr', 'plugins', 'heeler');
  const tailscale = () => {
    const command = settings.tailscaleCommand ?? [runtime.tailscale];
    if (!Array.isArray(command) || !command.length || command.some(a => typeof a !== 'string' || !a)) throw new Error('Invalid tailscaleCommand');
    return JSON.parse(run(command[0], [...command.slice(1), 'status', '--json']));
  };
  const setup = () => {
    const status = settings.addresses === undefined ? tailscale() : null;
    const defaults = pairingDefaults(settings, status);
    herdr(['plugin', 'link', pluginDirectory, '--enabled']);
    const directory = herdr(['plugin', 'config-dir', 'heeler']);
    if (!directory.startsWith('/')) throw new Error('Herdr returned no absolute plugin config directory');
    const result = ensurePairingConfig(directory, defaults);
    console.log(`Heeler plugin registered; ${result.customized ? 'keeping customized' : 'prepared'} ${result.path}`);
    return directory;
  };
  const command = args.shift();
  if (command === 'setup' || command === 'pair') {
    if (args.length) throw new Error('Unexpected arguments');
    setup();
    if (command === 'pair') {
      console.log('Opening the pairing popup in the current Herdr session; scan it within two minutes.');
      const output = herdr(['plugin', 'action', 'invoke', 'heeler.pair']);
      if (output) console.log(output);
    }
    return;
  }
  if (command === 'devices') {
    const action = args.shift() ?? 'list';
    if (action === 'list') {
      if (args.some(a => a !== '--json')) throw new Error('Unexpected arguments');
      const devices = listDevices(stateDir, home).map(({ line, ...record }) => record);
      if (args.includes('--json')) console.log(JSON.stringify(devices, null, 2));
      else if (!devices.length) console.log('No managed devices. Run heeler pair for each new device.');
      else for (const device of devices) console.log(`${JSON.stringify(device.label)}  ${device.fingerprint}  ${device.active ? 'authorized' : 'inactive'}`);
      return;
    }
    if (action !== 'rename' && action !== 'revoke') throw new Error('Unknown devices command');
    if (args.length !== (action === 'rename' ? 2 : 1)) throw new Error(`Usage: heeler devices ${action} ID${action === 'rename' ? ' NAME' : ''}`);
    const record = await changeDevice({ stateDir, home, identity: args[0], label: action === 'rename' ? args[1] : undefined });
    console.log(`${action === 'rename' ? 'Renamed' : 'Revoked SSH access for'} ${record.fingerprint}`);
    return;
  }
  if (command === 'doctor') {
    if (args.length) throw new Error('Unexpected arguments');
    let failures = 0;
    const check = async (name, fn) => {
      try { const detail = await fn(); console.log(`✓ ${name}${detail ? `: ${detail}` : ''}`); }
      catch (error) { failures++; console.log(`error: ${name}: ${error.message}`); }
    };
    await check('Node.js', () => process.versions.node);
    await check('Herdr', () => herdr(['--version']));
    await check('plugin', () => {
      const raw = JSON.parse(herdr(['plugin', 'list', '--plugin', 'heeler', '--json']));
      const plugins = raw.result?.plugins ?? raw.plugins ?? (Array.isArray(raw) ? raw : []);
      const plugin = plugins.find(p => p.plugin_id === 'heeler' || p.id === 'heeler');
      if (!plugin?.enabled || plugin.plugin_root !== pluginDirectory.replace(/\/$/, '')) {
        throw new Error('Run heeler setup to register and enable the packaged plugin');
      }
      return `heeler ${plugin.version}`;
    });
    await check('Tailscale addresses', () => pairingDefaults(settings, settings.addresses === undefined ? tailscale() : null).addresses.join(', '));
    await check('OpenSSH', async () => { await tcpBanner(settings.localSshPort ?? 22); return 'local SSH banner received'; });
    await check('Herdr socket', () => {
      const configHome = process.env.XDG_CONFIG_HOME ?? join(home, '.config');
      const selected = prefix[1] ?? process.env.HERDR_SESSION;
      const defaultSocket = selected && selected !== 'default' ? join(configHome, 'herdr', 'sessions', selected, 'herdr.sock') : join(configHome, 'herdr', 'herdr.sock');
      if (!existsSync(process.env.HERDR_SOCKET_PATH ?? defaultSocket)) throw new Error('Enter your existing Herdr session first');
      return 'present';
    });
    if (failures) throw new Error(`${failures} check(s) failed`);
    return;
  }
  throw new Error(`Unknown command: ${command}\n${help}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch(error => { console.error(`heeler: ${error.message}`); process.exitCode = 1; });
}
