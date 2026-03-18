# Security Assessment — OpenClaw + NemoClaw Gap Analysis

> Last updated: 2026-03-18
> Status: Initial assessment based on public research, CVEs, and academic papers

---

## Executive Summary

OpenClaw has been called "2026's first major AI agent security crisis." NemoClaw adds a useful runtime sandbox but leaves **critical gaps** in prompt injection, memory poisoning, supply chain trust, inter-agent authentication, and confused deputy attacks. Our project needs additional guardrails at every layer NemoClaw does not cover.

---

## 1. OpenClaw — Known Vulnerabilities & Incidents

### Critical CVEs

| CVE | CVSS | Description |
|-----|------|-------------|
| CVE-2026-25253 | 8.8 | **1-click RCE** — WebSocket origin not validated, malicious website gets full system access |
| CVE-2026-21636 | — | Permission model bypass |
| CVE-2026-22171 | — | Path traversal in Feishu media download |
| CVE-2026-22175 | — | Execution approval bypass via shell multiplexers (busybox, toybox) |
| CVE-2026-25593 | — | Command injection |
| CVE-2026-24763 | — | Authentication bypass |
| CVE-2026-25157 | — | Path traversal |
| CVE-2026-26322 | 7.6 | SSRF in Gateway tool |
| CVE-2026-26319 | 7.5 | Missing webhook authentication |
| CVE-2026-26329 | — | Path traversal in browser upload |

**January 2026 security audit found 512 total vulnerabilities, 8 critical.**

### Major Incidents

**ClawJacked** — Any website can silently hijack a developer's OpenClaw agent via WebSocket. No rate limiting on localhost password guesses. Post-compromise: read Slack history, exfiltrate files, execute shell commands.

**ClawHavoc** — 1,184 malicious skills identified on ClawHub (~1 in 5 packages). 335 skills distributed Atomic macOS Stealer. Snyk found 36.82% of all ClawHub skills contain security flaws.

**Moltbook Breach** — 1.5 million API tokens, 35,000 email addresses, and private agent messages exposed with zero access controls.

**30,000+ exposed instances** found by Bitsight, including Anthropic API keys, Telegram tokens, Slack accounts, and chat histories.

### Architectural Weaknesses

- **~500K lines of unaudited code**, 70+ dependencies
- **Host-level execution by default** — Docker sandbox is opt-in, most never enable it
- **Shared container for all agents** — no inter-agent isolation
- **Localhost trust assumption** — browsers can originate connections from localhost
- **Plaintext credential storage** — API keys stored unencrypted
- **TOCTOU race condition** in sandbox path validation (~25% success rate for escape)

### Government Responses
- **China**: Banned from government computers
- **South Korea**: Major tech companies restricted use
- **Belgium**: CCB issued critical vulnerability warning

---

## 2. NemoClaw — What It Protects

NemoClaw provides **runtime sandbox controls**:
- Kernel-level container isolation (OpenShell)
- Declarative YAML policies (file access, network, cloud services)
- Privacy Router (cloud vs. local model routing)
- Process isolation and privilege escalation blocking

---

## 3. NemoClaw — What It Does NOT Protect (Critical Gaps)

### Gap 1: Prompt Injection (OWASP ASI01)
**The fundamental problem.** Sandboxing operates at the system layer; prompt injection operates at the reasoning layer. A sandboxed agent that processes a poisoned document will follow injected instructions *inside* the sandbox using its legitimate permissions.

- 12 published defenses tested — most bypassed with >90% success rate
- Human red-teaming achieved 100% bypass across all defenses
- First malicious indirect prompt injection found in production (Palo Alto Unit 42, Dec 2025)

**Our guardrail needed:** Input sanitization layer, output monitoring, "Rule of Two" enforcement.

### Gap 2: Memory Poisoning (OWASP ASI06)
**No documented NemoClaw protection.** MINJA attack achieves >95% injection success rate. Poisoned instructions persist across sessions, trigger days/weeks later.

- Amazon Bedrock Agents memory poisoned via indirect prompt injection
- Microsoft found 50+ active memory poisoning operations across 31 companies
- NemoClaw restricts where memory is stored on disk, but cannot inspect content

**Our guardrail needed:** Memory integrity validation, content checksums, periodic memory auditing.

### Gap 3: Supply Chain / Malicious Skills (OWASP ASI04)
**NemoClaw does not audit skill content.** A malicious skill runs inside the sandbox with whatever permissions the YAML policy grants.

- 36.82% of ClawHub skills have security flaws (Snyk audit of 3,984 skills)
- Skills execute with full agent permissions
- Dual-vector attacks: 91% of malicious skills combine executable payloads + prompt injection
- Named threat actors actively publishing malicious skills

**Our guardrail needed:** Curated skill allowlist, mandatory audit before install, no direct ClawHub pulls.

### Gap 4: Confused Deputy Attacks (OWASP ASI02)
**NemoClaw policies control which tools are available, not how they're used within scope.** An agent tricked into using its legitimate email access to exfiltrate data is using tools exactly as configured.

- Asana MCP confused deputy: cross-org data exposure affecting ~1,000 enterprise customers
- Microsoft Copilot EchoLeak: zero-click vulnerability via email
- Tool authorization must happen *inside each tool function*, not at the sandbox level

**Our guardrail needed:** Per-request authorization in tool implementations, not just per-tool-group policies.

### Gap 5: Inter-Agent Trust (OWASP ASI07)
**NemoClaw provides per-agent isolation but no inter-agent authentication.** Agents cannot distinguish their owner from an impersonator.

- No mutual authentication between gateways
- Message injection between agents is possible
- ClawWorm: self-propagating worm with 85% success rate across OpenClaw ecosystems

**Our guardrail needed:** Mutual TLS, message signing, agent identity verification for ST-Gabriel ↔ Maria.

### Gap 6: Data Exfiltration via Allowed Tools
**If the agent needs web/messaging access, NemoClaw cannot prevent exfiltration.** Data encoded in URL parameters, hidden text in documents, image steganography.

- Any whitelisted domain becomes a potential exfiltration endpoint
- Privacy Router monitors model API calls but not all outbound tool traffic

**Our guardrail needed:** Output monitoring, DLP integration, strict URL allowlisting.

### Gap 7: Sandbox Escape
**OpenShell uses kernel-shared containers, not MicroVMs.** Known escape vectors:

- CVE-2025-23266 ("NVIDIAScape"): Flaw in NVIDIA Container Toolkit — **directly in NemoClaw's dependency chain**
- CVE-2025-52881: Container write redirection enabling host crash/breakout
- TOCTOU race condition in Node.js path validation (~25% success)

**Our guardrail needed:** Track NVIDIA Container Toolkit CVEs, consider MicroVM isolation for high-risk agents.

### Gap 8: Intent Drift / Rogue Agents (OWASP ASI10)
**NemoClaw cannot detect when an agent gradually drifts from its intended goals.** A compromised agent acting within its authorized scope looks identical to a healthy one.

**Our guardrail needed:** Behavioral monitoring, action logging, anomaly detection.

### Gap 9: The Sandbox Paradox
The core criticism: sandboxing is like "putting the dog in a crate with the documents." For agents to be useful, they need credentials. A sandbox cannot prevent abuse of legitimate credentials.

**Our guardrail needed:** "Rule of Two" — no agent should simultaneously process untrusted input, access sensitive data, AND communicate externally.

---

## 4. OWASP Agentic Top 10 Coverage

| OWASP ID | Risk | NemoClaw Covers? | Our Action Required |
|----------|------|-------------------|---------------------|
| ASI01 | Agent Goal Hijacking | NO | Input validation, prompt hardening |
| ASI02 | Tool Misuse | PARTIAL | Per-request auth in tools |
| ASI03 | Privilege Abuse | PARTIAL | Least-privilege YAML policies |
| ASI04 | Supply Chain | NO | Curated skill allowlist, audit |
| ASI05 | Code Execution | PARTIAL | Container hardening, CVE tracking |
| ASI06 | Memory Poisoning | NO | Memory integrity checks |
| ASI07 | Inter-Agent Comms | NO | mTLS, message signing |
| ASI08 | Cascading Failures | NO | Circuit breakers, isolation |
| ASI09 | Human Trust Exploit | NO | UX safeguards, confirmation flows |
| ASI10 | Rogue Agents | PARTIAL | Behavioral monitoring |

---

## 5. Recommended Guardrails for This Project

### Layer 1: Pre-Installation (Supply Chain)
1. **No direct ClawHub pulls** — maintain a curated, audited skill allowlist
2. **Mandatory `/dependency-audit`** before any package install
3. **Verify skill source matches published artifact** (reproducible builds)
4. **Block skills with `postinstall` scripts** unless manually reviewed
5. **Flag single-maintainer packages** and recent maintainer changes

### Layer 2: Configuration (Defense in Depth)
6. **Rule of Two enforcement** — no agent gets untrusted input + sensitive data + external comms simultaneously
7. **Least-privilege YAML policies** — start with deny-all, explicitly allow only what's needed
8. **Separate agents for separate trust domains** — don't share containers
9. **Strict URL allowlisting** — no wildcard web access
10. **No plaintext credential storage** — use NemoClaw-managed secrets or vault

### Layer 3: Runtime (Monitoring)
11. **Output monitoring** — log all tool invocations and external communications
12. **Memory integrity validation** — periodic auditing of agent memory stores
13. **Behavioral anomaly detection** — flag deviations from expected action patterns
14. **Rate limiting** — cap tool invocations per time window
15. **Circuit breakers** — halt agent on repeated failures or suspicious patterns

### Layer 4: Transport (ST-Gabriel ↔ Maria)
16. **Mutual TLS** between gateways
17. **Message signing** — every inter-agent message cryptographically signed
18. **Agent identity verification** — no anonymous agent communication
19. **Encrypted transport** — no plaintext between machines
20. **Audit trail** — every cross-machine interaction logged

### Layer 5: Development (Ongoing)
21. **Security Sentinel agent** reviews all code changes (already built)
22. **Pre-commit security checks** (already built)
23. **Track OpenClaw CVEs** — github.com/jgamblin/OpenClawCVEs/
24. **Track NVIDIA Container Toolkit CVEs** — especially CVE-2025-23266
25. **Regular NemoClaw updates** — alpha software, patches frequent

---

## 6. Key References

### CVE Tracking
- OpenClaw CVE tracker: github.com/jgamblin/OpenClawCVEs/

### Academic Papers
- "Don't Let the Claw Grip Your Hand" — arXiv 2603.10387
- "Taming OpenClaw" — arXiv 2603.11619
- "Uncovering Security Threats in Autonomous Agents" — arXiv 2603.12644
- "Clawdrain: Token Exhaustion" — arXiv 2603.00902
- "ClawWorm: Self-Propagating Agent Worm" — arXiv 2603.15727

### Industry Analysis
- Snyk ToxicSkills audit: snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/
- Oasis Security ClawJacked: oasis.security/blog/openclaw-vulnerability
- Trend Micro CISO analysis: trendmicro.com/en_us/research/26/c/cisos-in-a-pinch-a-security-analysis-openclaw.html
- Simon Willison Lethal Trifecta: simonw.substack.com/p/the-lethal-trifecta-for-ai-agents
- OWASP Agentic Top 10: genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/

### Vendor Guidance
- Microsoft: microsoft.com/en-us/security/blog/2026/02/19/running-openclaw-safely-identity-isolation-runtime-risk/
- NVIDIA Sandboxing Guide: developer.nvidia.com/blog/practical-security-guidance-for-sandboxing-agentic-workflows/
- Adversa AI hardening guide: adversa.ai/blog/openclaw-security-101-vulnerabilities-hardening-2026/
