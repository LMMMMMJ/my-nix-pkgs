# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a custom Nix flake providing packages not available or outdated in nixpkgs, including:
- AI CLI tools: `claude-code`, `gemini-cli`, `codex`
- Python packages: `tushare`, `pyexecjs`, `xtquant`, `regex`, and the HuggingFace family (`transformers`, `sentence-transformers`, `huggingface-hub`, `tokenizers`, `hf-xet`)

## Common Commands

```bash
# Build ALL packages at once (always use this instead of building one by one)
nix build .#claude-code .#gemini-cli .#codex .#tushare .#pyexecjs .#xtquant .#hf-xet .#huggingface-hub .#tokenizers .#transformers .#sentence-transformers

# Build a specific package
nix build .#claude-code

# Enter development shell (has all packages available)
nix develop

# After updating packages, ALWAYS verify in the dev shell — `nix build` only
# checks the package builds; this confirms CLIs launch and Python modules import
# at the expected versions.
nix develop --command bash -c '
  claude --version
  gemini --version
  codex --version
  python3 -c "
import importlib, importlib.metadata as md
for pkg in [\"tushare\",\"execjs\",\"hf_xet\",\"huggingface_hub\",\"tokenizers\",\"transformers\",\"sentence_transformers\"]:
    importlib.import_module(pkg)
    try: v = md.version(pkg.replace(\"_\",\"-\"))
    except Exception: v = \"unknown\"
    print(f\"{pkg}: {v}\")
"'

# Validate flake configuration
nix flake check

# Update flake dependencies
nix flake update
```

## Architecture

### Flake Structure

The flake provides two main outputs:
1. **`overlays.default`** - Extends nixpkgs with custom packages. Downstream users apply this overlay to get packages via `pkgs.python3Packages.*` or `pkgs.*`
2. **`packages.<system>.*`** - Direct package access for `nix build`

### Package Organization

```
pkgs/
├── claude-code/          # npm package using buildNpmPackage
├── gemini-cli/           # npm package
├── tushare/              # Python wheel package
├── pyexecjs/             # Python package
├── huggingface-family/   # Python packages with shared dependencies
│   ├── default.nix       # Defines dependency order
│   ├── hf-xet/
│   ├── huggingface-hub/
│   ├── tokenizers/
│   ├── transformers/
│   └── sentence-transformers/
└── dev-shell/            # Development environment
```

### Adding New Packages

**Python packages:**
1. Create `pkgs/my-package/default.nix` using `buildPythonPackage`
2. Add to overlay in `flake.nix` under `pythonPackagesExtensions`:
   ```nix
   my-package = python-final.callPackage ./pkgs/my-package { };
   ```
3. Expose in `packages` output:
   ```nix
   my-package = pkgs.python3Packages.my-package;
   ```

**Non-Python packages (npm, etc.):**
1. Create `pkgs/my-package/default.nix`
2. Add directly to overlay:
   ```nix
   my-package = final.callPackage ./pkgs/my-package { };
   ```
3. Expose in `packages` output

### HuggingFace Family Pattern

The `pkgs/huggingface-family/default.nix` demonstrates handling packages with interdependencies. It takes `python-final` and `python-prev` parameters and returns a `rec` attribute set to allow internal references.

### External Flake Integration

`codex` is imported from an external flake (`codex-nix`) rather than defined locally, showing how to integrate third-party flakes.

### Updating npm Packages (e.g., claude-code)

npm packages require updating both the version/hash and regenerating `package-lock.json`:
1. Update `version` and `src.hash` in `default.nix`
2. Run `npm install` in the package directory to regenerate `package-lock.json`
3. Update `npmDepsHash` (build will fail with correct hash if wrong)

## Commit Conventions

Each package change gets its own commit. Commit messages follow these patterns:

- **Version update:** `<package>: <old-version> -> <new-version>` (e.g., `claude-code: 2.1.77 -> 2.1.85`)
- **New package:** `<package>: init at <version>` (e.g., `xtquant: init at 250516.1.1`)
- **Remove package:** `<package>: remove package`
- **Flake lock update:** `flake.lock: update nixpkgs <old-date> -> <new-date>`

## Multi-branch Update Workflow

This repo maintains three long-lived branches that pin different `nixpkgs` channels:

| Branch | `nixpkgs` pin | Notes |
| --- | --- | --- |
| `master` | `nixos-unstable` | Primary development branch |
| `nixos-25.11` | `nixos-25.11` | Stable channel; no `torch` override |
| `nixos-24.11` | `nixos-24.11` (+ `nixpkgs-newer` = `nixos-25.11`) | Compatibility branch with backport overlay |

**Every package update must be propagated across all three branches in this order:**

1. **`master` first.** Apply the update, build, run the dev-shell verification block, commit per the conventions above, then `git push`.
2. **`nixos-25.11` next.** Switch to the branch and either cherry-pick the master commit(s) or re-apply by hand. Re-run `nix build` + dev-shell verification (the pinned `nixpkgs` differs, so hashes/dependencies may diverge). Commit and push.
3. **`nixos-24.11` last.** Same flow; this branch is a *compatibility* branch — if upstream requires a toolchain newer than what 24.11 + `nixpkgs-newer` can supply, **skip the update on this branch** rather than forcing it. Note the skip in the push summary.

CLAUDE.md changes themselves are part of this rotation: a workflow rule only takes effect on the branch where it lives, so port doc updates to all three branches too.

When in doubt about whether an upgrade is safe on an older branch, prefer "skip + report" over a speculative bump.
