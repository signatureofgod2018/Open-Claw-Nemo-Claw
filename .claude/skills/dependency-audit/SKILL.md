---
name: dependency-audit
description: Audit a package dependency for supply chain security risks before adding it to the project
version: 0.1.0
user-invocable: true
---

# Dependency Audit

Perform a supply chain security audit on a package before adding it as a dependency.

## Usage
Invoke with: `/dependency-audit <package-name>`

## What This Skill Checks

### Package Health
1. **Popularity & Trust**: npm download counts, GitHub stars, age of package
2. **Maintainer Risk**: Number of maintainers, recent maintainer changes, account age
3. **Known Vulnerabilities**: CVEs, npm advisories, Snyk database
4. **Dependency Tree**: Transitive dependencies — how deep, any known-bad packages?
5. **Install Scripts**: Does it run `preinstall` or `postinstall` scripts?
6. **Source Match**: Does the published npm artifact match the GitHub source?

### Red Flags (auto-block)
- Single maintainer who recently gained access
- `postinstall` scripts that download or execute remote code
- Dependency on packages with known critical CVEs
- Typosquatting (name similar to a popular package)
- Obfuscated or minified source in a non-build package
- Wildcard or overly broad version ranges in dependencies

### Yellow Flags (manual review)
- Fewer than 2 active maintainers
- No recent releases (potential abandonment)
- Maintainer change in last 6 months
- Large number of transitive dependencies
- Permissions beyond stated purpose

## Reference Incidents
- **CVE-2024-3094 (XZ Utils)**: Compromised maintainer inserted backdoor into liblzma targeting OpenSSH. Went undetected for months. Single social-engineered maintainer.
- **event-stream (2018)**: Maintainer handed off package to attacker who added cryptocurrency-stealing code via a transitive dependency.
- **ua-parser-js (2021)**: Popular npm package compromised — cryptominer + password stealer injected.
- **colors.js / faker.js (2022)**: Maintainer intentionally sabotaged widely-used packages.
- **node-ipc (2022)**: Maintainer added destructive code targeting specific geolocations.

## Output
Produces a security report with PASS / WARN / FAIL verdict and detailed findings.
