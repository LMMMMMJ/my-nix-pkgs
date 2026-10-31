import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { generateBootstrapKey } from '../src/bootstrap-key.js';
import { beginPairing, endPairing } from '../src/pairing-session.js';
import { changeDevice, listDevices } from './device-registry.mjs';
import { ensurePairingConfig, main, pairingDefaults } from './cli.mjs';

const temporary = () => mkdtempSync(join(tmpdir(), 'nix-heeler-'));
const save = (path, value) => writeFileSync(path, `${JSON.stringify(value)}\n`, { mode: 0o600 });

test('two real enrollments survive popup cleanup; revocation preserves another device and unrelated SSH keys', async () => {
  const accountRoot = temporary();
  try {
    const stateDir = join(accountRoot, 'plugin-state');
    const sshDirectory = join(accountRoot, '.ssh');
    mkdirSync(sshDirectory, { mode: 0o700 });
    const unrelated = `${generateBootstrapKey().publicLine} original-laptop`;
    writeFileSync(join(sshDirectory, 'authorized_keys'), `${unrelated}\n`, { mode: 0o600 });
    const ceremonies = [];
    for (const name of ['iPad', 'iPhone']) {
      const ceremony = await beginPairing({ home: accountRoot, stateDir });
      ceremonies.push(ceremony);
      const result = spawnSync(process.execPath, [fileURLToPath(new URL('../src/pair-accept.js', import.meta.url)),
        '--state-dir', stateDir, '--pairing-id', ceremony.pairingId], {
        input: `${generateBootstrapKey().publicLine} ${name}\n`, encoding: 'utf8',
        env: { HOME: accountRoot, PATH: '' }, timeout: 5000,
      });
      assert.equal(result.status, 0, result.stderr);
      assert.match(result.stdout, /^HERDR-ENROLL:OK:SHA256:/);
    }
    for (const ceremony of ceremonies) await endPairing({ home: accountRoot, stateDir, pairingId: ceremony.pairingId });
    const devices = listDevices(stateDir, accountRoot);
    assert.equal(devices.length, 2);
    assert.ok(devices.every(device => device.active));
    const selected = devices.find(device => device.label === 'iPad');
    const keyFile = join(sshDirectory, 'authorized_keys');
    const restricted = `restrict,command="echo preserve spaces" ${selected.line}`;
    const unrelatedOptions = `command="echo ${selected.line}" ${unrelated}`;
    writeFileSync(keyFile, readFileSync(keyFile, 'utf8').replace(selected.line, restricted) + `${unrelatedOptions}\n`);
    assert.ok(listDevices(stateDir, accountRoot).find(d => d.fingerprint === selected.fingerprint).active);
    await changeDevice({ stateDir, home: accountRoot, identity: selected.fingerprint, label: 'My iPad' });
    await changeDevice({ stateDir, home: accountRoot, identity: 'My iPad' });
    const remaining = listDevices(stateDir, accountRoot);
    assert.equal(remaining.length, 1);
    assert.equal(remaining[0].label, 'iPhone');
    assert.equal(remaining[0].active, true);
    const keys = readFileSync(join(sshDirectory, 'authorized_keys'), 'utf8');
    assert.ok(keys.includes(unrelated));
    assert.ok(keys.includes(unrelatedOptions));
    assert.ok(keys.includes(remaining[0].line));
    assert.ok(!keys.includes(restricted));
    assert.equal(statSync(join(sshDirectory, 'authorized_keys')).mode & 0o777, 0o600);
    const otherUser = temporary();
    try { assert.deepEqual(listDevices(join(otherUser, 'plugin-state'), otherUser), []); }
    finally { rmSync(otherUser, { recursive: true, force: true }); }
  } finally { rmSync(accountRoot, { recursive: true, force: true }); }
});

test('generated defaults refresh after an address change and preserve an explicit user override', () => {
  const directory = temporary();
  try {
    const status = { BackendState: 'Running', Self: { TailscaleIPs: ['100.64.0.10'], DNSName: 'host.example.ts.net.' } };
    const defaults = pairingDefaults({}, status);
    assert.deepEqual(defaults, { ssh_port: 22, addresses: ['100.64.0.10', 'host.example.ts.net'] });
    assert.equal(ensurePairingConfig(directory, defaults).customized, false);
    const changed = { ssh_port: 22, addresses: ['100.64.0.11'] };
    ensurePairingConfig(directory, changed);
    assert.deepEqual(JSON.parse(readFileSync(join(directory, 'pair.json'), 'utf8')), changed);
    const custom = { ssh_port: 2222, addresses: ['my-vps.example'], launcher: '/my/custom/launcher' };
    save(join(directory, 'pair.json'), custom);
    assert.equal(ensurePairingConfig(directory, defaults).customized, true);
    assert.deepEqual(JSON.parse(readFileSync(join(directory, 'pair.json'), 'utf8')), custom);
    assert.equal(statSync(join(directory, 'pair.json')).mode & 0o777, 0o600);
    assert.throws(() => pairingDefaults({}, { BackendState: 'NeedsLogin' }), /Sign in/);
    assert.throws(() => pairingDefaults({ sshPort: 0, addresses: ['host'] }), /port/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test('per-user setup uses its own Tailscale command and leaves credentials and notifications untouched', async () => {
  const root = temporary();
  try {
    const settingsDirectory = join(root, 'settings');
    mkdirSync(settingsDirectory);
    for (const [username, address] of [['jacob', '100.64.0.20'], ['lifan', '100.64.0.21']]) {
      const accountRoot = join(root, username); mkdirSync(accountRoot);
      const config = join(accountRoot, 'plugin-config'); mkdirSync(config);
      const notifications = '{"v":1,"devices":[{"token":"existing-device"}]}\n';
      writeFileSync(join(config, 'notifications.json'), notifications, { mode: 0o600 });
      save(join(settingsDirectory, `${username}.json`), { sshPort: 22, tailscaleCommand: [`/${username}/tailscale`] });
      const calls = [];
      await main(['setup', '--session', 'work'], {
        username, home: accountRoot, stateDir: join(accountRoot, 'state'),
        runtime: { herdr: '/packaged/herdr', tailscale: '/wrong/tailscale', settingsDirectory, requireSettings: true },
        execute(binary, args) {
          calls.push([binary, args]);
          if (binary === `/${username}/tailscale`) return JSON.stringify({ BackendState: 'Running', Self: { TailscaleIPs: [address] } });
          assert.equal(binary, '/packaged/herdr');
          assert.deepEqual(args.slice(0, 2), ['--session', 'work']);
          if (args.includes('config-dir')) return config;
          assert.ok(args.includes('link')); return 'linked';
        },
      });
      assert.deepEqual(JSON.parse(readFileSync(join(config, 'pair.json'), 'utf8')).addresses, [address]);
      assert.equal(readFileSync(join(config, 'notifications.json'), 'utf8'), notifications);
      assert.equal(existsSync(join(accountRoot, '.ssh')), false);
      assert.equal(calls.filter(([binary]) => binary === `/${username}/tailscale`).length, 1);
    }
    await assert.rejects(main(['setup'], {
      username: 'unconfigured', home: root,
      runtime: { settingsDirectory, requireSettings: true },
    }), /No Heeler defaults/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
