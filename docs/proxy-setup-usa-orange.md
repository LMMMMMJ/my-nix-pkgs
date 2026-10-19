# Two-Hop Proxy Chain — Complete Setup Guide (Relay → Exit)

> **Goal of this document:** anyone, with zero prior context, can reproduce the entire proxy chain from scratch by reading only this file.
> Assumed reader: comfortable with basic Linux commands and SSH, but knows nothing about this particular setup.
>
> ⚠️ **This document is redacted.** All keys, passwords, UUIDs, and real server IPs are shown as `<PLACEHOLDERS>`. Replace them with your own values (generation commands are in the text). **Never commit real secrets to this repository.**

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Glossary](#2-glossary)
3. [Prerequisites](#3-prerequisites)
4. [Master Parameter Table](#4-master-parameter-table)
5. [Step 1 — Exit Server (EXIT)](#5-step-1--exit-server-exit)
6. [Step 2 — Relay Server (RELAY)](#6-step-2--relay-server-relay)
7. [Step 3 — Open the Cloud Firewall](#7-step-3--open-the-cloud-firewall)
8. [Step 4 — Client Setup](#8-step-4--client-setup)
9. [Verifying the Whole Chain](#9-verifying-the-whole-chain)
10. [Daemon / Auto-start / Auto-restart](#10-daemon--auto-start--auto-restart)
11. [Common Operations](#11-common-operations)
12. [Troubleshooting (Important)](#12-troubleshooting)
13. [Appendix — Deriving the Public Key from the Private Key](#13-appendix--deriving-the-public-key)
14. [Security Notes](#14-security-notes)

---

## 1. Architecture Overview

This is a **two-hop proxy chain**: client traffic first reaches a "relay" server, which forwards it to an "exit" server, and the traffic finally egresses from the exit server's IP.

Benefits: the client faces the most censorship-resistant entry point (VLESS + Reality); the real exit IP lives on a separate machine and can be swapped without touching client config; the relay's own traffic also egresses through the exit.

```
                          ┌────────────────────────┐         ┌──────────────────────┐
   Your device            │   RELAY                 │         │   EXIT                │
 (FlClash / Shadowrocket) │   <RELAY_IP>            │         │   <EXIT_IP>           │
        │                 │                         │         │                       │
        │  VLESS+Reality  │  sing-box               │   SS    │  sing-box             │
        │  (TCP <V_PORT>) │  ┌───────────────────┐  │aes-256  │  ┌────────────────┐  │
        ├────────────────►│  │ vless inbound      │──┼────────►│  │ ss inbound     │──┼──► Internet
        │                 │  └───────────────────┘  │(<SS_PORT>) └────────────────┘  │  (exit IP =
        │                 │  ┌───────────────────┐  │         │   direct egress       │   <EXIT_IP>)
        │                 │  │ tun (hijack local) │──┘         │                       │
        │                 │  └───────────────────┘            └──────────────────────┘
        └─────────────────┴─────────────────────────┘

Data flow:
  (1) Client → RELAY:<V_PORT>   (VLESS+Reality encrypted)
  (2) RELAY routes everything (final) to to-exit (Shadowsocks)
  (3) to-exit → EXIT:<SS_PORT>  (Shadowsocks encrypted)
  (4) EXIT egresses directly; the public source IP seen by the internet = <EXIT_IP>

End result: visiting https://api.ipify.org on the client should show <EXIT_IP>.
```

| Machine | Role | What it runs | Egress IP |
| --- | --- | --- | --- |
| **EXIT** (exit / landing) | `<EXIT_IP>` | sing-box: Shadowsocks server → direct egress | itself |
| **RELAY** (relay / jump) | `<RELAY_IP>` | sing-box: VLESS-Reality inbound + tun + forward to EXIT | EXIT |

> Ops tip: set up passwordless SSH from RELAY to EXIT (`Host exit` in `RELAY:~/.ssh/config`) to form a `local → RELAY → EXIT` management path.

---

## 2. Glossary

- **sing-box**: the proxy core (program). It can act as both server and client. Both machines run it.
- **233boy/sing-box**: a script that automates installing and configuring sing-box (command: `sb`). See `https://github.com/233boy/sing-box`.
- **VLESS**: a lightweight proxy protocol. It carries no encryption of its own; it relies on the outer TLS/Reality layer.
- **Reality**: a TLS camouflage technique that borrows a real major site's TLS handshake (here `aws.amazon.com`). It needs **no domain or certificate of your own** and is the most censorship-resistant option.
- **xtls-rprx-vision (flow)**: the flow-control companion to Reality that reduces traffic-fingerprinting.
- **Shadowsocks (SS)**: a classic symmetric-encryption proxy, used here for the RELAY→EXIT internal backhaul.
- **tun**: a virtual NIC created by sing-box that hijacks the host's *own* traffic into sing-box (so the relay's own traffic also egresses through EXIT).

---

## 3. Prerequisites

1. **Two VPSes** (Debian/Ubuntu, root): one as the exit (clean route, IP not blocked) and one as the relay (**your client must be able to reach it directly** — this is the most critical point).
2. Both can reach GitHub.
3. **Access to your VPS provider's cloud firewall / security group console** (to open ports — the biggest pitfall of this setup).
4. A client: **FlClash** (mihomo core) on Windows/macOS/Linux, **Shadowrocket** on iOS.
   ⚠️ Plain Clash does **not** support Reality — you must use the **Meta (mihomo)** core.

---

## 4. Master Parameter Table

> Replace every `<PLACEHOLDER>` with your own value. **Do not put real values in this repository** — keep them in a private note, or just read them from the server config files.

| Parameter | Placeholder | How to generate / obtain | Used where |
| --- | --- | --- | --- |
| Exit server IP | `<EXIT_IP>` | the VPS public IP | RELAY outbound + route exclude |
| Relay server IP | `<RELAY_IP>` | the VPS public IP | client connection address |
| Relay /24 subnet | `<RELAY_SUBNET>/24` | if RELAY IP is a.b.c.d, use a.b.c.0/24 | tun exclude (keeps SSH alive) |
| Shadowsocks port | `<SS_PORT>` (e.g. 24433) | your choice | EXIT inbound / RELAY outbound |
| Shadowsocks method | `aes-256-gcm` | fixed | must match on both ends |
| Shadowsocks password | `<SS_PASSWORD>` | `openssl rand -base64 24` | must match on both ends |
| VLESS port | `<V_PORT>` (e.g. 2083) | your choice (sync firewall + client if changed) | client connection port |
| VLESS UUID | `<VLESS_UUID>` | `sing-box generate uuid` | server + client |
| VLESS flow | `xtls-rprx-vision` | fixed | server + client |
| Reality private key | `<REALITY_PRIVATE_KEY>` | `sing-box generate reality-keypair` | **RELAY server only** |
| Reality public key | `<REALITY_PUBLIC_KEY>` | the PublicKey from the same command | **client only** |
| Reality SNI / handshake host | `aws.amazon.com:443` | pick a reachable TLS 1.3 major site | server + client |
| Reality short_id | empty `""` | fixed (or your own) | server + client |
| Client fingerprint | `chrome` | fixed | client |

---

## 5. Step 1 — Exit Server (EXIT)

EXIT is just a plain Shadowsocks server that egresses directly. A single-file config is enough.

### 5.1 Install sing-box (233boy)

```bash
bash <(wget -qO- https://raw.githubusercontent.com/233boy/sing-box/master/install.sh)
```
This provides the `sb` command, the binary at `/etc/sing-box/bin/sing-box`, and a systemd service named `sing-box`.

### 5.2 Write the config

```bash
cat > /etc/sing-box/config.json <<'JSON'
{
  "log": { "output": "/var/log/sing-box/access.log", "level": "info", "timestamp": true },
  "inbounds": [
    {
      "type": "shadowsocks",
      "tag": "exit-ss-in",
      "listen": "::",
      "listen_port": <SS_PORT>,
      "method": "aes-256-gcm",
      "password": "<SS_PASSWORD>"
    }
  ],
  "outbounds": [ { "type": "direct", "tag": "direct" } ],
  "route": { "auto_detect_interface": true, "final": "direct" }
}
JSON
```

### 5.3 Validate, start, enable on boot

```bash
/etc/sing-box/bin/sing-box check -c /etc/sing-box/config.json
systemctl enable --now sing-box
systemctl restart sing-box
ss -tlnp | grep <SS_PORT>
```

### 5.4 EXIT cloud firewall
Allow **TCP `<SS_PORT>`** inbound (ideally restrict the source to `<RELAY_IP>/32`).

---

## 6. Step 2 — Relay Server (RELAY)

RELAY does three things: (1) a VLESS-Reality inbound for clients; (2) forward all traffic to EXIT; (3) a tun that also hijacks the host's own traffic through EXIT.

### 6.1 Install sing-box
```bash
bash <(wget -qO- https://raw.githubusercontent.com/233boy/sing-box/master/install.sh)
```

### 6.2 Generate the Reality key pair and UUID
```bash
/etc/sing-box/bin/sing-box generate reality-keypair
#   PrivateKey: <REALITY_PRIVATE_KEY>   <- goes into the server node file
#   PublicKey:  <REALITY_PUBLIC_KEY>    <- goes into the client (pbk)
/etc/sing-box/bin/sing-box generate uuid    # -> <VLESS_UUID>
```

### 6.3 Config layout

Use the **233boy split layout** (so `sb` can manage the node):
```
/etc/sing-box/
├── config.json                       # base: log + dns + tun + to-exit outbound + route
└── conf/
    └── VLESS-REALITY-<V_PORT>.json    # the vless node
```
systemd starts it with `sing-box run -c config.json -C conf`, which merges the two.

### 6.4 Base config `config.json`

```bash
cat > /etc/sing-box/config.json <<'JSON'
{
  "log": { "output": "/var/log/sing-box/access.log", "level": "info", "timestamp": true },
  "dns": {
    "servers": [
      { "type": "tls", "tag": "dns-remote", "server": "1.1.1.1", "server_port": 853, "detour": "to-exit" },
      { "type": "local", "tag": "dns-local" }
    ],
    "final": "dns-remote",
    "strategy": "ipv4_only"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "sb-tun0",
      "address": [ "172.19.0.1/30", "fdfe:dcba:9876::1/126" ],
      "mtu": 9000,
      "auto_route": true,
      "auto_redirect": true,
      "strict_route": true,
      "route_exclude_address": [
        "<EXIT_IP>/32",
        "<RELAY_SUBNET>/24",
        "127.0.0.0/8",
        "::1/128",
        "fc00::/7",
        "fe80::/10"
      ]
    },
    { "type": "mixed", "tag": "local-mixed", "listen": "127.0.0.1", "listen_port": 2080 }
  ],
  "outbounds": [
    {
      "type": "shadowsocks",
      "tag": "to-exit",
      "server": "<EXIT_IP>",
      "server_port": <SS_PORT>,
      "method": "aes-256-gcm",
      "password": "<SS_PASSWORD>"
    },
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "auto_detect_interface": true,
    "default_domain_resolver": "dns-local",
    "rules": [
      { "action": "sniff" },
      { "protocol": "dns", "action": "hijack-dns" },
      {
        "ip_cidr": [
          "<EXIT_IP>/32",
          "<RELAY_SUBNET>/24",
          "127.0.0.0/8",
          "10.0.0.0/8",
          "172.16.0.0/12",
          "192.168.0.0/16",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outbound": "direct"
      }
    ],
    "final": "to-exit"
  }
}
JSON
```

**Key points (understand these, they are easy to get wrong):**

- `dns`: the host's DNS goes over **DoT (`type:"tls"`, TCP) via to-exit**. You **must** use a TCP-based type, because Shadowsocks UDP relay is unreliable — `udp`-type DNS frequently fails. `strategy: ipv4_only` avoids broken IPv6.
- The two route rules `{"action":"sniff"}` and `{"protocol":"dns","action":"hijack-dns"}` are **required on sing-box 1.12+**. Without them, in tun mode DNS falls into a "connect to itself" loop and the whole host loses network (see Troubleshooting, Pitfall 2).
- `route_exclude_address` **must** include:
  - `<EXIT_IP>/32`: otherwise the RELAY→EXIT traffic gets re-hijacked by the tun, forming a loop.
  - `<RELAY_SUBNET>/24`: **lifesaver** — keeps SSH out of the tun so editing/restarting sing-box won't drop you.
- `final: "to-exit"`: any traffic not matched by a rule (client traffic and host traffic alike) egresses through EXIT.
- To make certain fixed IPs (e.g. your home egress) go direct, add `<your_ip>/32` to both `route_exclude_address` and `ip_cidr`.

### 6.5 Node file `conf/VLESS-REALITY-<V_PORT>.json`

```bash
mkdir -p /etc/sing-box/conf
cat > /etc/sing-box/conf/VLESS-REALITY-<V_PORT>.json <<'JSON'
{
  "inbounds": [
    {
      "tag": "VLESS-REALITY-<V_PORT>.json",
      "type": "vless",
      "listen": "::",
      "listen_port": <V_PORT>,
      "users": [ { "flow": "xtls-rprx-vision", "uuid": "<VLESS_UUID>" } ],
      "tls": {
        "enabled": true,
        "server_name": "aws.amazon.com",
        "reality": {
          "enabled": true,
          "handshake": { "server": "aws.amazon.com", "server_port": 443 },
          "private_key": "<REALITY_PRIVATE_KEY>",
          "short_id": [ "" ]
        }
      }
    }
  ],
  "outbounds": [
    { "type": "direct" },
    { "tag": "public_key_<REALITY_PUBLIC_KEY>", "type": "direct" }
  ]
}
JSON
```

**Notes:**
- The `tag` uses the filename `VLESS-REALITY-<V_PORT>.json` — that is the 233boy naming convention, and `sb` relies on it to recognize the node.
- The `public_key_<REALITY_PUBLIC_KEY>` placeholder direct outbound is **not a real outbound** — it is where 233boy **stores the Reality public key** so that `sb` can read it back when displaying the share link.
- The `private_key` lives on the server only and **never** goes into the client.

### 6.6 Validate, start, enable on boot
```bash
/etc/sing-box/bin/sing-box check -c /etc/sing-box/config.json -C /etc/sing-box/conf
systemctl enable --now sing-box
systemctl restart sing-box
ss -tlnp | grep -E '<V_PORT>|2080'
```

> ⚠️ **Restarting sing-box briefly drops your current SSH session** (the tun's strict_route resets the conntrack table). Just reconnect after a few seconds — this is normal. SSH won't truly break because `<RELAY_SUBNET>/24` is in the exclude list.

---

## 7. Step 3 — Open the Cloud Firewall

> **The most common point of failure.** If the server is configured and local self-tests pass but clients can't connect, 99% of the time this step was skipped.

In the **RELAY VPS console**, allow **TCP `<V_PORT>`** inbound (protocol TCP, source 0.0.0.0/0 or restricted to your egress IP). **Make sure it's a persistent rule.**
If you change the VLESS port later, you must open the new port too.

---

## 8. Step 4 — Client Setup

The client connects to the **RELAY IP + VLESS port**. **The public key (pbk) goes to the client; the private key never does.**

### 8.1 FlClash / Clash.Meta (mihomo) — YAML
```yaml
proxies:
  - name: "relay-to-exit"
    type: vless
    server: <RELAY_IP>
    port: <V_PORT>
    uuid: <VLESS_UUID>
    network: tcp
    udp: true
    tls: true
    flow: xtls-rprx-vision
    servername: aws.amazon.com
    client-fingerprint: chrome
    reality-opts:
      public-key: <REALITY_PUBLIC_KEY>
      # short-id can be left empty; some old mihomo builds choke on short-id: "" — if so, delete this line
```
⚠️ Must be the Meta (mihomo) core (FlClash / Clash Verge Rev / mihomo / Stash); plain Clash does not support Reality.

### 8.2 Shadowrocket / generic `vless://` link
```
vless://<VLESS_UUID>@<RELAY_IP>:<V_PORT>?encryption=none&flow=xtls-rprx-vision&security=reality&sni=aws.amazon.com&fp=chrome&pbk=<REALITY_PUBLIC_KEY>&type=tcp#relay-to-exit
```
Manual entry: Type VLESS / Address `<RELAY_IP>` / Port `<V_PORT>` / UUID `<VLESS_UUID>` / Encryption none / flow `xtls-rprx-vision` / Transport tcp / Security reality / SNI `aws.amazon.com` / Fingerprint chrome / pbk `<REALITY_PUBLIC_KEY>` / shortID empty.

---

## 9. Verifying the Whole Chain

### 9.1 Client side
After connecting, visit **https://api.ipify.org**. It should show **`<EXIT_IP>`**.
- Shows `<EXIT_IP>` → the chain works ✅
- Shows `<RELAY_IP>` → traffic only reached the relay, not forwarded to the exit (check RELAY's `route.final`)
- Can't connect → go to Troubleshooting (section 12)

### 9.2 Server-side self-test (on RELAY, no client needed)
```bash
cat > /tmp/selftest.json <<'JSON'
{"log":{"level":"warn"},"inbounds":[{"type":"mixed","listen":"127.0.0.1","listen_port":18099}],
"outbounds":[{"type":"vless","tag":"out","server":"<RELAY_IP>","server_port":<V_PORT>,
"uuid":"<VLESS_UUID>","flow":"xtls-rprx-vision",
"tls":{"enabled":true,"server_name":"aws.amazon.com","utls":{"enabled":true,"fingerprint":"chrome"},
"reality":{"enabled":true,"public_key":"<REALITY_PUBLIC_KEY>","short_id":""}}}]}
JSON
/etc/sing-box/bin/sing-box run -c /tmp/selftest.json &  P=$!
sleep 3
curl -sS -x http://127.0.0.1:18099 --max-time 15 https://api.ipify.org; echo   # expect <EXIT_IP>
kill $P

curl -sS --max-time 12 https://api.ipify.org; echo   # host's own egress (via tun), expect <EXIT_IP>
getent hosts github.com                               # DNS resolving means it's healthy
```

---

## 10. Daemon / Auto-start / Auto-restart

Both machines' sing-box run under systemd, unit `/usr/lib/systemd/system/sing-box.service`:
```ini
ExecStart=/etc/sing-box/bin/sing-box run -c /etc/sing-box/config.json -C /etc/sing-box/conf
Restart=on-failure              # crash / abnormal exit -> auto-restart
RestartPreventExitStatus=23     # exit code 23 (config error) does NOT restart, to avoid a crash loop
WantedBy=multi-user.target      # start on boot
```
- Both are `enabled` + `Restart=on-failure`: auto-restart on crash, auto-start on boot.
- RELAY's tun/routes/nftables are created by sing-box at startup, so they are **rebuilt automatically after a service restart or full reboot**.
- ⚠️ `RestartPreventExitStatus=23`: on a config error (exit code 23) it **deliberately does not restart** — you must fix the config manually. Always `sing-box check` before `restart`.

Optional hardening (more resilient): change `Restart=on-failure` to `Restart=always`, add `RestartSec=5s` and `StartLimitIntervalSec=0`, then `systemctl daemon-reload && systemctl restart sing-box`.

Handy commands: `systemctl status sing-box` / `journalctl -u sing-box -n 50 --no-pager` / `tail -f /var/log/sing-box/access.log`.

---

## 11. Common Operations

**Change the VLESS port (old → NNNN):**
```bash
cd /etc/sing-box
jq '(.inbounds[0].listen_port)=NNNN' conf/VLESS-REALITY-<old>.json > /tmp/n && mv /tmp/n conf/VLESS-REALITY-<old>.json
mv conf/VLESS-REALITY-<old>.json conf/VLESS-REALITY-NNNN.json   # optional: keep the naming convention; sync the inner tag too
/etc/sing-box/bin/sing-box check -c config.json -C conf && systemctl restart sing-box
```
After changing: (1) open the new port in the cloud firewall; (2) update the client's port.

**Manage nodes with `sb`**: run `sb` for the interactive menu — list nodes, show share link / QR, add/remove nodes.
> ⚠️ **Do not use `sb`'s "fix-config" / reinstall**: it regenerates `config.json` from the 233boy template (only log/dns/outbounds) and would **wipe this setup's custom tun + to-exit chain + dns + route**. Safe operations: view link, add/remove node, change port.

**Swap the exit server**: change only the RELAY — set the `to-exit` outbound `server` and the old exit IP in the route to the new IP, `check`, then `restart`. The client needs no changes.

**Rollback**: before any major edit, `cp config.json config.json.bak.$(date +%s)`.

---

## 12. Troubleshooting

> Pitfalls actually hit while building this. **Golden rule: first determine whether it's "can't reach the server" vs. a "config/handshake problem".**

### Determine whether packets reach the server
Capture on RELAY while the client tries to connect:
```bash
apt-get install -y tcpdump
tcpdump -nni any 'tcp port <V_PORT>'
```
- No packets from the client → network-layer problem (firewall / route / client not actually dialing).
- SYN arrives but the handshake never completes → config/handshake problem.
You can also test from an **overseas** machine using sing-box as a client with the same parameters (most representative of real external access).

### Pitfall 1 — Client can't connect, times out with no response (most common)
- **Cause A: the cloud firewall doesn't allow the VLESS port** — the #1 cause. It works instantly once opened.
  Verify: from outside, `Test-NetConnection <RELAY_IP> -Port <V_PORT>` (Windows) or `nc -vz <RELAY_IP> <V_PORT>`. Only `TcpTestSucceeded: True` counts.
- **Cause B: the client's local network / bypass-router blocks it** — actually happened here. On the client machine, **bypass the proxy app** and run `Test-NetConnection` directly; if that also fails, investigate the local router/bypass-router/firewall.
- **Cause C: a non-standard port is targeted by the ISP/GFW** — prefer ports that look like normal HTTPS (443/8443/2053/2083).

### Pitfall 2 — After enabling tun, the whole host loses network and DNS fails
- **Symptom**: `ping IP` works but all domain lookups fail; access.log repeatedly shows `tun → direct connection to 172.19.0.x:53` looping.
- **Cause**: tun mode lacks DNS handling — no `dns` block and no `hijack-dns` route rule. sing-box 1.12+ removed the old automatic DNS-hijack-in-tun behavior.
- **Fix**: add the `dns` block (DoT via to-exit) and the `sniff` + `hijack-dns` route rules as in section 6.4.

### Pitfall 3 — DNS via the exit fails
- **Cause**: a `udp`-type DNS server was used, but Shadowsocks UDP relay is unreliable.
- **Fix**: use `"type":"tls"` (DoT, TCP) with `detour: to-exit`.

### Pitfall 4 — Local self-test works but external clients can't connect
- **Cause**: a self-test on RELAY connecting to `<RELAY_IP>` goes over loopback and bypasses the real network/firewall.
- **Fix**: always test from **outside**; the root cause is usually Pitfall 1 (firewall).

### Pitfall 5 — Plain Clash can't connect to Reality
- **Fix**: switch to a Meta (mihomo) core client.

### Pitfall 6 — Lost the Reality public key (only the private key remains)
- See section 13 to derive it; or read it from the `public_key_xxx` placeholder outbound tag in the 233boy node file.

---

## 13. Appendix — Deriving the Public Key

Reality uses X25519; the public key = X25519(private_key, basepoint 9). The private key is base64url (43 chars = 32 bytes).

**Method 1: openssl**
```bash
python3 -c '
import base64,sys
priv="<REALITY_PRIVATE_KEY>"   # your private key
raw=base64.urlsafe_b64decode(priv+"="*((-len(priv))%4))
sys.stdout.buffer.write(bytes.fromhex("302e020100300506032b656e04220420")+raw)
' | openssl pkey -inform DER -pubout -outform DER 2>/dev/null | tail -c 32 \
  | python3 -c 'import sys,base64;print(base64.urlsafe_b64encode(sys.stdin.buffer.read()).rstrip(b"=").decode())'
```

**Method 2**: in `conf/VLESS-REALITY-*.json`, the `XXXX` in `"tag":"public_key_XXXX"` under `outbounds` is the public key.

**Method 3**: `sing-box generate reality-keypair` to make a fresh pair (sync server + client).

---

## 14. Security Notes

- **Private key, SS password, and UUID** are the keys to this proxy — never share, screenshot, or commit them. **This document intentionally uses placeholders only.**
- Giving the public key (pbk) to the client is fine; the private key (private_key) lives **only on the RELAY server** and never goes to clients.
- Tighten firewall sources where possible: restrict EXIT's SS port to `<RELAY_IP>`; restrict SSH (22) to your usual IP.
- Keep real values in a private place (the server config files are themselves the source of truth) — never write them into this repository.

---

## Quick Reference — Shortest Reproduction Path

1. **EXIT**: install 233boy → overwrite `config.json` (SS inbound) → `check` → `enable --now` → open the SS port in the firewall.
2. **RELAY**: install 233boy → generate reality key pair / UUID → write `config.json` (dns+tun+to-exit+route) → write `conf/VLESS-REALITY-<V_PORT>.json` → `check -c config.json -C conf` → `enable --now` → open the VLESS port in the firewall.
3. **Client**: import the YAML/link from section 8 → visit https://api.ipify.org, which should show `<EXIT_IP>`.

Done.
