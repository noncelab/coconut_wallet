---
name: check-electrum-cert-fingerprints
description: Check whether pinned SSL certificate fingerprints for default Electrum servers in lib/enums/electrum_enums.dart have changed, and update them if necessary.
allowed-tools:
  - read
  - grep
  - edit
  - exec
  - write
permissions:
  allow:
    - Read(lib/enums/electrum_enums.dart)
    - Write(lib/enums/electrum_enums.dart)
    - Exec(openssl)
    - Write(.agents/skills/check-electrum-cert-fingerprints/last_run.txt)
---

Check whether the pinned SSL certificate fingerprints for default Electrum servers in `lib/enums/electrum_enums.dart` have changed, and update them if necessary.

1. Read `lib/enums/electrum_enums.dart`.
2. Find every `DefaultElectrumServer` enum value whose `ElectrumServer` has a non-null `pinnedCertFingerprint`.
3. For each such server, run the following command to fetch the current certificate's SHA-256 fingerprint:
   ```bash
   echo | openssl s_client -connect <host>:<port> -servername <host> 2>/dev/null | openssl x509 -noout -fingerprint -sha256
   ```
   Extract the fingerprint from the `SHA256 Fingerprint=<AA:BB:...>` output.
4. Compare the fetched fingerprint with the existing `pinnedCertFingerprint`. Normalize both to upper-case `AA:BB:...` format before comparing.
5. If any fingerprint differs, update the corresponding string in `lib/enums/electrum_enums.dart` with the newly fetched fingerprint. Preserve the existing indentation and code style.
6. Record today's date (YYYY-MM-DD, local time) in `.agents/skills/check-electrum-cert-fingerprints/last_run.txt`, overwriting any previous content. Use exactly one line with no extra explanation.
7. Report the results:
   - List every server checked (host:port).
   - For each server, state whether the fingerprint matched or was updated.
   - If updates were made, mention the file path and that the `last_run.txt` date was recorded.
   - If the check command fails for a server, report the failure and continue checking the remaining servers.
