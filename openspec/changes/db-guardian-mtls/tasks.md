# Tasks: DB Guardian Mutual TLS

Implementation checklist. See [design.md](design.md) for how, specs/ for what.

Shape: phase 1 is **generation A** — certificates and sops wiring, no behaviour change, deployed to every host. Phase 2 is **generation B** — one module generation, committed once, deployed to every host in a single window: guardians first, the database primary last. There is no transitional port, no dual-protocol listener and no compatibility shim; drain and undrain are unavailable for the duration of that window (design, Decision 5).

Sequencing: no dependency on `reallocate-server-service-roles`, and no certificate is reissued when it moves the primary. The coordinator host comes from the module's existing primary predicate (`isThisIOPrimaryHost` today, `isThisPrimaryHost config.server.databasePrimaryHost` after that change lands) and the guardian set from `getOthersWhere` / `getOthersWhereExcept` — both derived in `modules/nixos/server/database/guardian.nix`, never a literal hostname.

## Status

What is done in this branch, and what is not:

- **Implemented and unit-tested:** the mutual-TLS listener with the peer-certificate allowlist, the `wss://` coordinator client with hostname verification, PSK removal from both binaries and from the module, the mandatory-allowlist assertion, the `db-guardian` user with its polkit rule, the systemd hardening set, and the documentation.
- **Blocked on material that is not in this repository:** generation A's certificate files. 1.3-1.6 need the offline `Fleet mTLS Root CA` private key to sign the DB Guardian intermediate, and 2.17 needs a SOPS data key to rewrite `hosts/server/secrets.yaml`. Neither key exists in the workspace this was prepared in.
- **Handed to the operator:** 2.20b and 2.21-2.23. The cutover window is not run from here.

Until 1.3-1.6 land, the unit references `hosts/server/<host>/db-guardian-tls/*`, so the hosts evaluate but cannot build.

---

## 1. Pre-flight and certificates (generation A)

Pre-flight first: it decides how the allowlist is implemented before any code depends on it. Everything here has no behavioural effect — the guardian still speaks plaintext-PSK and the coordinator still dials `ws://` at the end of the phase.

- [x] 1.1 **Pre-flight, before any allowlist code**: against the pinned `websockets` version in `pkgs/db-guardian/`, confirm on a live TLS connection that the server can read the *verified* peer certificate — `get_extra_info("peercert")` on the transport, as `pkgs/alloy-dynamic-capture/api.py` does — and record the exact call and its return shape in the commit message. If it is not exposed, adopt the documented fallback: an `ssl.SSLContext` subclass that records the peer certificate during the handshake (`sni_callback` / `wrap_bio`) and exposes it to the connection. No allowlist task starts until this is settled (design: Decision 8 — How the peer certificate is reached)
- [ ] 1.2 **Pre-flight**: `nix build` every affected host (`nixcloud`, `nixdev`, `nixserv`, and the database primary) at the current HEAD, so a cutover failure is attributable to the cutover and not to pre-existing breakage Status: `nix build` cannot run in this container (no builder); each affected host was evaluated instead.
- [ ] 1.3 Create the `DB Guardian Intermediate CA` offline under the Fleet mTLS root using the documented procedure — intermediate key stays offline, never committed (spec: `db-guardian-security/spec.md`, design: Decision 1) Status: blocked -- the Fleet root CA private key is offline and not present in this workspace.
- [ ] 1.4 Issue one `serverAuth` leaf per guardian host with SANs `<host>`, `<host>.localdomain`, `<host>.${server.proxy.domain}`; sign each with the guardian intermediate and build the chain with `cat <leaf>.crt <intermediate>.crt` — the host set is the expression in 1.7, not a hand-written list (spec: `db-guardian-security/spec.md`, design: Decision 3) Status: blocked -- depends on 1.3.
- [ ] 1.5 Issue one `clientAuth` leaf with `CN=db-guardian-coordinator` for the host the primary predicate selects — `nixio` on today's topology; if `reallocate-server-service-roles` has already landed, the same leaf for `nixdb` and nothing else changes (spec: `db-guardian-security/spec.md`, design: Decision 4) Status: blocked -- depends on 1.3.
- [ ] 1.6 Write the leaves as binary sops files under `hosts/server/<host>/db-guardian-tls/` — `CA_CERT`, `SERVER_CERT`, `SERVER_KEY` on every guardian, plus `CLIENT_CERT`, `CLIENT_KEY` on the database primary — and confirm the existing `path_regex: hosts/server/<host>/` rules in `.sops.yaml` select the right recipients, adding a host rule only if that host has none (design: Decision 1, proposal Impact/Secrets) Status: blocked -- depends on 1.3-1.5, and no age key for these recipients is present in this workspace.
- [x] 1.7 Add a `guardianSopsFile` helper and `sops.secrets` declarations in `modules/nixos/server/database/guardian.nix`, mirroring `alloySopsFile` (`format = "binary"`, `sopsFile = "${hostDirectory}/db-guardian-tls/${name}"`), guarded by the same `isThisIOPrimaryHost` / `getOthersWhere` expressions that decide which units exist, with `restartUnits` listing only the units the host defines — as the existing `DB_GUARDIAN_PSK` declaration does today (spec: `db-guardian-security/spec.md`, design: Decision 1)
- [x] 1.8 Add `users.users.db-guardian` / `users.groups.db-guardian` in `modules/nixos/server/database/guardian.nix` — `isSystemUser = true`, no home, no login shell (spec: `db-guardian-security/spec.md`, design: Decision 6)
- [ ] 1.9 Deploy generation A to all guardian hosts and the database primary; verify each secret decrypts and its credential path exists (`test -s /run/secrets/db-guardian/…`) before generation B is built (design: Migration Plan 1) Status: blocked -- depends on 1.3-1.6.

**Validation after Group 1**: every affected host builds; on each host the sops units activated and the credential files are non-empty. Guardian and coordinator still speak plaintext-PSK; the wire is byte-for-byte the current one.

## 2. Single-window cutover (generation B)

One commit, one module generation, one window. Every task in this group lands together — in particular, **no commit may remove `--psk-file` from a unit while `pkgs/db-guardian/{server,client}.py` still require it**: the deployed binary and the deployed unit must agree, so 2.8 and 2.9, and 2.13 and 2.15, are the same change.

**Server**
- [x] 2.1 `pkgs/db-guardian/server.py` — build an `ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)` with `minimum_version = TLSv1_2`, `verify_mode = ssl.CERT_REQUIRED`, `load_cert_chain`, `load_verify_locations`, and pass it to `serve(..., ssl=context)` at the call site now at `server.py:431` (spec: `db-guardian-security/spec.md`, design: Decision 2)
- [x] 2.2 `pkgs/db-guardian/server.py` — add `--ca-cert`, `--server-cert`, `--server-key`, `--allowed-cn` (repeatable); keep `--port` and `--host` (spec: `db-guardian-security/spec.md`)
- [x] 2.3 `pkgs/db-guardian/server.py` — enforce the allowlist per connection using the mechanism settled in 1.1 (transport `peercert` or the `SSLContext` subclass fallback): extract the common name, close with code 1008 on mismatch before any frame is consumed, log the observed CN (spec: `db-guardian-security/spec.md`, design: Decision 8)
- [x] 2.4 `pkgs/db-guardian/server.py` — refuse to start when the allowlist is empty, returning non-zero from `async_main` before constructing the listener; do **not** port the fail-open branch at `api.py:88` (spec: `db-guardian-security/spec.md`, design: Decision 8)
- [x] 2.5 `pkgs/db-guardian/server.py` — extend `run_tests()` with cases for: empty allowlist refuses to start, unknown CN is rejected, matching CN proceeds to command handling (spec: `db-guardian-security/spec.md`)
- [x] 2.6 `modules/nixos/server/database/guardian.nix` — add `--ca-cert`, `--server-cert`, `--server-key`, `--allowed-cn` to `db-guardian.service`'s `ExecStart`, sourced from `%d/` credentials; add a `server.database.guardian.allowedClientCommonNames` option defaulting to `[ "db-guardian-coordinator" ]` (spec: `db-guardian-security/spec.md`, design: Decision 3, Decision 8)
- [x] 2.7 `modules/nixos/server/database/guardian.nix` — add the Nix assertion that `allowedClientCommonNames != [ ]` so an empty allowlist is an evaluation error, not a runtime one (spec: `db-guardian-security/spec.md`, design: Decision 8)
- [x] 2.8 `modules/nixos/server/database/guardian.nix` — replace the plaintext listener with the TLS listener on **9876** (same port, no second port, no firewall change) and remove the guardian's `--psk-file` argument, in the same commit as 2.9 (design: Decision 5, Decision 9)
- [x] 2.9 `pkgs/db-guardian/server.py` — delete `load_psk()`, the `--psk-file` argument, the `psk` parameter of `handle_client`, the `{"type":"auth"}` branch including the `provided_key == psk` comparison at `server.py:253`, and the `authenticated_clients` set; do not replace the comparison with `hmac.compare_digest` (spec: `db-guardian-security/spec.md`, design: Decision 7)
- [x] 2.10 `pkgs/db-guardian/server.py` — make the first accepted frame a `command`, and return `Unknown message type: auth` for a stale client so version skew is obvious in logs (design: Decision 5)
- [x] 2.11 `modules/nixos/server/database/guardian.nix` — remove the `DB_GUARDIAN_PSK` `LoadCredential` from `db-guardian.service` (line 136) and the PSK argument at line 142 (design: Decision 5)

**Coordinator**
- [x] 2.12 `pkgs/db-guardian/client.py` — replace `ws://{host}:{port}` at `client.py:76` with `wss://`, and build the context with `ssl.create_default_context(cafile=ca_cert)` followed by `load_cert_chain(client_cert, client_key)`, leaving `CERT_REQUIRED` and `check_hostname` at their defaults (spec: `db-guardian-security/spec.md`, design: Decision 2, Decision 3)
- [x] 2.13 `pkgs/db-guardian/client.py` — add `--ca-cert`, `--client-cert`, `--client-key`; remove `--psk-file` and `GUARDIAN_PSK_FILE`; add no flag that disables verification (spec: `db-guardian-security/spec.md`)
- [x] 2.14 `pkgs/db-guardian/client.py` — delete `load_psk()` and the `{"type":"auth","key":…}` frame at `client.py:82`, and drop the auth-response handling that follows it (spec: `db-guardian-security/spec.md`)
- [x] 2.15 `modules/nixos/server/database/guardian.nix` — add the client certificate credentials to `db-database-coordinator.service` and `db-database-coordinator-reconcile.service`, remove `--psk-file` / the PSK `LoadCredential` from both (lines 226, 232, 240 and 258, 264) in this same generation, and keep `--port` at **9876** — there is no intermediate port to point at (spec: `db-guardian-security/spec.md`, design: Decision 5)

**PSK removal, in the same generation as the code that stops reading it**
- [x] 2.16 `modules/nixos/server/database/guardian.nix` — remove the `sops.secrets."DB_GUARDIAN_PSK"` declaration (line 76) and its `restartUnits` wiring (lines 80-84) (spec: `db-guardian-security/spec.md`)
- [ ] 2.17 `hosts/server/secrets.yaml` — remove the `DB_GUARDIAN_PSK` entry (sops edit, not a plain text edit) (spec: `db-guardian-security/spec.md`, design: Decision 5) Status: blocked -- rewriting this file requires a SOPS data key, and no age key is present in this workspace.
- [x] 2.18 `pkgs/db-guardian/client.py` — extend `run_tests()` with a case asserting the context has `verify_mode == CERT_REQUIRED` and `check_hostname is True`, so a future edit cannot quietly relax it (spec: `db-guardian-security/spec.md`)
- [x] 2.19 `pkgs/db-guardian/client.py` — surface certificate verification failures as a distinct error in the per-host result rather than folding them into `OSError`, so a SAN mismatch is diagnosable from `journalctl -u db-database-coordinator` (design: Risks — SAN mismatch)

**The window**
- [ ] 2.20 Confirm the generation is coherent before deploying: `rg -- '--psk-file|DB_GUARDIAN_PSK|load_psk|"auth"' pkgs/db-guardian modules/nixos/server/database hosts/server` returns nothing, and the phase-2 changes are one commit — no earlier commit in the branch removes a `--psk-file` argument (design: Decision 5 — What still has to be ordered) Status: fails as written -- `hosts/server/secrets.yaml` still carries `DB_GUARDIAN_PSK` because 2.17 is blocked.
- [ ] 2.20b **Pre-check, immediately before the window opens** (numbered `2.20b` so the window tasks keep their IDs): on the database primary, run `nixos-rebuild dry-activate --flake .#<primary>` on generation B and confirm the unit-restart list contains `db-database-coordinator.service` and `db-database-coordinator-reconcile.service` and does **not** contain `postgresql.service`; record the list in the window log. If `postgresql.service` is listed, do not open the window — the primary's switch would restart PostgreSQL inside the interval that has no drain path (design: Decision 5) Status: not run -- requires the database primary host; the expected restart list is in the handoff.
- [ ] 2.21 Open the window with PostgreSQL up. Deploy generation B to the guardians first (`nixcloud`, `nixdev`, `nixserv`); after each switch, verify from the database primary with `openssl s_client -connect <host>:9876 -CAfile CA_CERT -cert CLIENT_CERT -key CLIENT_KEY -verify_hostname <host>`, and verify a wrong-CN certificate is refused. Accept that drains fail from here — that is the cost of the window, and the reconcile timer recovers it Status: not run -- window tasks are handed to the operator.
- [ ] 2.22 Deploy generation B to the database primary **last**. Its rebuild restarts `db-database-coordinator.service` and `db-database-coordinator-reconcile.service` only — PostgreSQL's unit inputs are unchanged, so `postgresql.service` must **not** restart. If the switch would restart `postgresql.service`, stop the window before switching: once the guardians are switched the drain cannot be delivered, so a PostgreSQL restart here is unannounced downtime for every dependent service. After the switch, confirm `journalctl -u db-database-coordinator` shows `wss://` connections Status: not run -- window tasks are handed to the operator.
- [ ] 2.23 Close the window only after observing one full reconcile sweep: every guardian reports `undrained`, and a manual `systemctl restart db-database-coordinator.service` still drains and undrains (design: Decision 5 — Cost, Migration Plan 2) Status: not run -- window tasks are handed to the operator.

**Validation after Group 2**: `./result/bin/db-guardian-server test` and `db-guardian-client test` pass; `openssl s_client` succeeds on 9876 for each guardian and fails with a certificate not signed by the guardian intermediate; drain and undrain both succeed end to end over 9876 with no PSK anywhere; `/run/secrets` contains no guardian PSK; `ss -ltnp` shows only 9876 listening and the firewall opens only 9876.

## 3. Non-root identity and polkit

Separate from the transport cutover so a privilege failure cannot compound with a protocol failure.

- [ ] 3.1 Verify on **one** guardian that polkit authorises the rule for a target: with the daemon temporarily run as `db-guardian`, issue a drain and confirm `org.freedesktop.systemd1.manage-units` is logged with `unit == "db-databases.target"` and `verb == "stop"`, and that the target stops. If `action.lookup("unit")` is empty or the rule does not fire, stop and take the Decision 6 fallback (sudoers + `subprocess systemctl`) before continuing (design: Decision 6 — Fallback, Risks) Status: not run -- requires a live guardian.
- [x] 3.2 `modules/nixos/server/database/guardian.nix` — add `security.polkit.extraConfig` with the rule from design Decision 6: `manage-units`, `unit == "db-databases.target"`, `verb` in `start`/`stop`, `subject.user == "db-guardian"` (spec: `db-guardian-security/spec.md`, design: Decision 6)
- [x] 3.3 `modules/nixos/server/database/guardian.nix` — add `User = "db-guardian"` and `Group = "db-guardian"` to `db-guardian.service`, and delete the "Run as root to allow systemctl commands" comment it invalidates (lines 145-146) (spec: `db-guardian-security/spec.md`)
- [x] 3.4 `pkgs/db-guardian/server.py` — confirm the state-wait path still works unprivileged: `Unit.load()` reads `ActiveState` and `Upholds`, which are readable on the system bus; adjust `run_systemctl` only if the guard against `DBusError` is insufficient (design: Decision 6 — Read access)
- [ ] 3.5 Deploy to one guardian, drain and undrain it, and confirm `ps -o user= -p $(systemctl show -p MainPID --value db-guardian.service)` reports `db-guardian` and that a manual `systemctl restart db-guardian.service` still drains dependents (spec: `db-guardian-security/spec.md`) Status: not run -- requires a live guardian.
- [ ] 3.6 Deploy to the remaining guardians (spec: `db-guardian-security/spec.md`) Status: not run -- requires the remaining guardians.

**Validation after Group 3**: the daemon runs as `db-guardian`; drain and undrain succeed; `systemctl restart postgresql.service` on the database primary still drains and re-undrains every guardian.

## 4. systemd hardening

- [x] 4.1 `modules/nixos/server/database/guardian.nix` — add to `db-guardian.service`: `ProtectSystem = "strict"`, `NoNewPrivileges = true`, `CapabilityBoundingSet = [ ]`, `AmbientCapabilities = [ ]`, `RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ]`, `RestrictNamespaces = true`, `LockPersonality = true`, `ProtectControlGroups = true`, `ProtectClock = true`, `ProtectHostname = true`, `ProtectProc = "invisible"`, `RemoveIPC = true`, `UMask = "0077"` (spec: `db-guardian-security/spec.md`)
- [x] 4.2 `modules/nixos/server/database/guardian.nix` — add `SystemCallFilter = [ "@system-service" ]` with `SystemCallErrorNumber = "EPERM"`; keep `ProtectHome`, `PrivateTmp`, `PrivateDevices`, `ProtectKernelTunables`, `ProtectKernelModules` (spec: `db-guardian-security/spec.md`)
- [ ] 4.3 `modules/nixos/server/database/guardian.nix` — evaluate (do not assume) whether `MemoryDenyWriteExecute = true` survives Python plus the `pystemd` C extension; keep it only if `db-guardian-server test` and a live drain pass (design: Open Question 2) Status: evaluated, not enabled -- a syscall trace of the pinned interpreter running this daemon (real mTLS handshake, real pystemd dispatch) makes zero `mmap`/`mprotect` calls that request `PROT_EXEC`, `libffi` is not linked into any pystemd or websockets extension, and the interpreter has no JIT. The remaining gate is a live drain on one host, so the directive stays out of this generation; add `MemoryDenyWriteExecute = true;` in the commit that passes 4.4.
- [ ] 4.4 Deploy to one guardian and drain it; if any directive breaks the D-Bus path, `systemd-analyze security --offline=yes` and the unit journal identify it (design: Risks — polkit) Status: not run -- requires a live guardian.

**Validation after Group 4**: `systemd-analyze security db-guardian.service` shows a materially lower exposure score than before, and drain/undrain still succeed on the hardened host.

## 5. Documentation

- [x] 5.1 `docs/src/components/db_guardian.md` — replace the PSK description (line ~19) and rewrite the Secrets section (lines 130-139) with the mTLS model: who holds which certificate, which CN is allowed, where the secrets live (spec: `db-guardian-security/spec.md`, `AGENTS.md`)
- [x] 5.2 `docs/src/components/db_guardian.md` — replace the auth-frame protocol reference (lines 98-115, including the `{"type":"auth"}` request and response) with the post-change protocol: first frame is a `command`, no auth message (spec: `db-guardian-security/spec.md`)
- [x] 5.3 `docs/src/components/db_guardian.md` — rewrite the secrets table row at line 139 and the troubleshooting entries that reference `DB_GUARDIAN_PSK` (lines 184, 185, 205) in favour of certificate expiry, CN mismatch, SAN mismatch, and polkit denial; state at the port note (line 145) that 9876 is TLS-only from the cutover, with no transitional port (spec: `db-guardian-security/spec.md`)
- [x] 5.4 `docs/src/modules/nixos/server/database.md` — replace the PSK sentence at line ~46 and the secrets bullet at line ~55 with the guardian certificate secrets and where they live (spec: `db-guardian-security/spec.md`)
- [x] 5.5 `docs/src/security/internal_mtls_ca.md` — add the `DB Guardian Intermediate CA` to the trust hierarchy diagram, the consumers table, the key-custody note, and the secret-layout table (`hosts/server/<host>/db-guardian-tls/{CA_CERT,SERVER_CERT,SERVER_KEY,CLIENT_CERT,CLIENT_KEY}`) (design: Decision 1, Decision 10)
- [x] 5.6 `docs/src/security/internal_mtls_ca.md` — add the guardian to the rotation and verification examples so the intermediate rotation procedure names all three services (design: Risks — no revocation)

**Validation after Group 5**: `rg -n "PSK|psk" docs/src` returns no guardian references; the `docs` build (typos/markdown) passes; every doc line changed is in the same commit as the code it describes.

## 6. Final verification

- [x] 6.1 Run `nix fmt .` (spec: `db-guardian-security/spec.md`, `AGENTS.md`)
- [x] 6.2 `./result/bin/db-guardian-server test` and `./result/bin/db-guardian-client test` pass (spec: `db-guardian-security/spec.md`) Status: run through the pinned Python 3.14 interpreter and its `websockets`/`pystemd`, because the container cannot build `./result`.
- [ ] 6.3 Build each affected host: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` for `nixcloud`, `nixdev`, `nixserv`, and the database primary (spec: `db-guardian-security/spec.md`) Status: blocked -- depends on generation A certificates.
- [ ] 6.4 `nix flake check --override-input devenv-root "file+file://$PWD/.devenv/root"` (spec: `db-guardian-security/spec.md`) Status: not run -- `nix flake check` needs a builder, which this container does not have.
- [ ] 6.5 Negative test: from a host that is not the database primary but holds a valid monitoring relay certificate, attempt a drain against a guardian over TLS and confirm the connection is refused (spec: `db-guardian-security/spec.md`, design: Decision 1) Status: not run -- requires hosts.
- [x] 6.6 Negative test: start the guardian with an empty `--allowed-cn` and confirm it exits non-zero without binding (spec: `db-guardian-security/spec.md`, design: Decision 8) Status: verified locally -- the process exits 1 with `Refusing to start: at least one --allowed-cn is required`.
- [ ] 6.7 Availability test: stop and start PostgreSQL on the database primary and confirm every guardian drains and re-undrains within one reconcile interval, unchanged from current behaviour (spec: `db-guardian-security/spec.md`) Status: not run -- requires the database primary and every guardian.
- [ ] 6.8 Confirm no transitional surface survives: `ss -ltnp` on each guardian shows 9876 and nothing else, the firewall opens 9876 only, and `rg -n '9877' pkgs modules hosts` returns nothing (design: Decision 9) Status: partial -- no `9877` reference exists in `pkgs`, `modules` or `hosts`; the `ss` and firewall checks need the hosts.

---

## Task Dependency Summary

```
Group 1 (Pre-flight + certs + sops, generation A)  <- prerequisite for everything; 1.1 gates 2.3
  └── Group 2 (Generation B: server TLS, client wss://, PSK removal) — one commit, one window,
      guardians first and the database primary last
        ├── Group 3 (Non-root + polkit; 3.1 precedes 3.3 everywhere)
        │     └── Group 4 (Hardening)
        └── Group 5 (Documentation, finalised)
              └── Group 6 (Verification)
```

Groups 3 and 4 are independent of 5. Group 3.1 (polkit verification on one host) gates 3.3 (the `User=` change) on every host — if it fails, the Decision 6 fallback replaces 3.2-3.4 before anything else proceeds.

## Risk Notes

- **The window has no drain path (2.21-2.23).** From the first guardian switch until the coordinator's first undrain sweep, no drain or undrain can be delivered. Schedule it with PostgreSQL up, switch the guardians first, the database primary last, and do not restart PostgreSQL on the primary inside the window. An aborted window is finished or reverted on all four hosts — never left mixed, because a reverted host speaks a protocol its peers no longer do.
- **PSK removal is the point of no return (2.9-2.17).** It is one commit and one generation: `--psk-file`, `load_psk()`, the auth frame, the `DB_GUARDIAN_PSK` declaration and the secret itself all go together. Rollback means restoring the secret from git history and redeploying the previous guardian and coordinator generations on all four hosts.
- **A unit must never drop `--psk-file` while the binary still requires it.** 2.8 and 2.9 are the same commit, as are 2.13 and 2.15; 2.20 is the check that no earlier commit in the branch broke that rule.
- **Certificates before units (1.7-1.9).** A `LoadCredential` pointing at a sops secret that failed to decrypt fails the unit, and `Restart = "always"` turns that into a restart loop on every guardian.
- **SAN drift.** The SANs in 1.4 and the `--hosts` value in the module must be generated from the same expressions (`networking.hostName`, `networking.domain`). A hand-written SAN set will drift the first time a host is renamed.
- **Peer-certificate hook (1.1).** If `get_extra_info("peercert")` does not expose the verified certificate on the pinned `websockets`, the `SSLContext` subclass fallback is adopted before 2.3 is written — not discovered half-way through the allowlist.
- **Polkit fallback changes the code path.** The sudoers fallback in design Decision 6 replaces pystemd with `subprocess` + `systemctl`, which is a different failure mode (exit codes and stderr instead of D-Bus errors). If it is taken, the `run_systemctl` tests in 2.5 need a case for it.
