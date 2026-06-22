---
diataxis_type: how-to
---
# Add a plugin to the catalog

A plugin joins this marketplace by being **cataloged**: its repo attests its own
tarball, you add a SHA-pinned entry to `marketplace.json`, and CI re-verifies
those attestations **fail-closed** before the entry can merge. A plugin SHA that
does not verify does not enter the catalog.

The flow:

```
author plugin → its repo attests its tarball (provenance + SBOM + gate verdicts)
  → add a git-subdir + sha entry to marketplace.json
  → catalog-admission re-verifies the attestations fail-closed
  → merge
```

## Before you start

- The plugin must follow the
  [canonical layout](../../README.md#layout-canonical): a
  `.claude-plugin/plugin.json` with required `name`, `description`, and
  `author.name`, plus any of `commands/ agents/ skills/ hooks/ .mcp.json`.
- The plugin's source repo must produce an **attested tarball** — SLSA build
  provenance, a CycloneDX SBOM, and the seam-signed gate verdicts — at a specific
  commit. Catalog admission verifies *those* attestations; it does not re-scan
  the plugin from scratch.

## 1. Resolve the source commit SHA

Pin to an immutable 40-char commit SHA, never a tag or branch. Resolve it at use
time:

```bash
gh api repos/<owner>/<plugin-repo>/git/ref/tags/<tag> \
  --jq '.object.sha'
```

## 2. Add a `git-subdir` + `sha` entry to `marketplace.json`

Append an entry to the `plugins` array. The `sha` is the effective pin — when
both `ref` and `sha` are present, the digest is the identity and the ref is only
a human-readable label.

```jsonc
{
  "name": "<plugin-name>",            // unique within this marketplace
  "description": "<one-line summary>",
  "author": { "name": "<author>" },
  "source": {
    "source": "git-subdir",           // plugin lives in a subdirectory of a repo
    "repo": "<owner>/<plugin-repo>",  // the external plugin's source repo
    "subdir": "plugins/<plugin-name>",// path to the plugin within that repo
    "ref": "v1.2.3",                  // human-readable label (mutable)
    "sha": "<40-char-commit-sha>"     // EFFECTIVE PIN — immutable identity
  },
  "license": "<SPDX-id>",
  "keywords": ["<...>"]
}
```

> The vendored `attested-reference` plugin lives **inside** this repo, so its
> entry uses a local `"source": "./plugins/attested-reference"` path rather than
> `git-subdir`. External plugins use the `git-subdir` + `sha` form above.

## 3. Open a PR — catalog admission runs fail-closed

The pull request triggers the marketplace gates. Two are decisive for admission:

- **manifest-review** (`manifest/v1`) — fails closed unless every external plugin
  source is SHA-pinned, the marketplace `name` is not a reserved name, and the
  required manifest fields are present.
- **catalog admission** — re-verifies the plugin's published attestations
  (provenance, SBOM, gate verdicts) for the pinned SHA. If any attestation fails
  to verify, admission fails and the entry cannot merge.

`claude plugin validate` runs as the canonical manifest check alongside these.

## 4. Verify, then merge

In-pipeline green is not the acceptance test. Re-verify the pinned plugin's
attestations independently from a clean workstation before approving — the exact
commands are in [SECURITY.md](../../SECURITY.md#verify-a-plugin-release) and
[../security/verify.md](../security/verify.md).

Once admission passes and the attestations re-verify, merge. The merged
`marketplace.json` is re-signed (cosign keyless) as part of the release so
consumers can prove they fetched the catalog this repo published.

## Updating a cataloged plugin

To move a plugin to a newer version, **re-pin its `sha`** to the new commit and
let catalog admission re-verify the new digest's attestations. Never edit a
plugin's content in place behind an unchanged SHA — a different content hash is a
different artifact, and the old attestations do not describe it.

### Automated re-pins (the attested catalog-updater)

You normally don't re-pin external plugins by hand. The central, **verify-first**
catalog-updater hub in
[`attested-delivery/.github`](https://github.com/attested-delivery/.github/tree/main/catalog-update)
does it for you: on a schedule it resolves each external entry's **latest
release**, **verifies that release's attestations fail-closed**, and — only if
every required predicate verifies — opens a re-pin PR whose body carries the full
attestation evidence. The PR runs through `catalog-admission` (which re-verifies
the same way) and **auto-merges once the gates are green**. A release whose
attestations don't verify is never proposed.

This catalog opts in by having the `attested-delivery-ci` App installed — there is
no per-repo workflow to add. (Dependabot can't do this: no Dependabot ecosystem
parses the `git-subdir` + `sha` catalog pins; its `github-actions` updater here
only keeps the workflow `uses:` pins fresh.)
