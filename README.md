# 🛡️ Security Headers Checker

[![GitHub Marketplace](https://img.shields.io/badge/GitHub%20Marketplace-Qualtio%20Security%20Headers%20Checker-red)](https://github.com/marketplace/actions/security-headers-checker)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A GitHub Action that validates the **HTTP security headers** of a deployed application and fails the pipeline if required headers are missing or misconfigured — enforcing security posture as part of your CI/CD workflow.

Based on [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/) recommendations.

---

## Checked Headers

| Header | Importance | Protects Against |
|---|---|---|
| `Strict-Transport-Security` | 🔴 Critical | SSL stripping, MITM |
| `X-Content-Type-Options` | 🔴 Critical | MIME sniffing attacks |
| `X-Frame-Options` | 🔴 Critical | Clickjacking |
| `Content-Security-Policy` | 🟠 High | XSS, data injection |
| `Permissions-Policy` | 🟠 High | Browser feature abuse |
| `Referrer-Policy` | 🟡 Medium | Information leakage |
| `Cross-Origin-Opener-Policy` | 🟡 Medium | Spectre-type attacks |
| `Cross-Origin-Resource-Policy` | 🟡 Medium | Cross-origin data leaks |
| `Cache-Control` | 🟡 Medium | Sensitive data caching |

---

## Usage

### Check headers after deployment

```yaml
name: Security Headers Check

on:
  deployment_status:

jobs:
  headers:
    if: github.event.deployment_status.state == 'success'
    runs-on: ubuntu-latest
    steps:
      - uses: qualtio/security-headers-checker@v1
        with:
          url: ${{ github.event.deployment_status.target_url }}
```

### Custom required and warning headers

```yaml
- uses: qualtio/security-headers-checker@v1
  with:
    url: 'https://staging.your-app.com'
    fail-on-missing: 'Strict-Transport-Security,X-Content-Type-Options,Content-Security-Policy'
    warn-on-missing: 'Permissions-Policy,Referrer-Policy'
```

### Generate a JSON report as artifact

```yaml
- uses: qualtio/security-headers-checker@v1
  id: headers
  with:
    url: 'https://your-app.com'
    report-file: '/tmp/headers-report.json'

- uses: actions/upload-artifact@v4
  with:
    name: security-headers-report
    path: /tmp/headers-report.json
```

### Use score in subsequent steps

```yaml
- id: headers
  uses: qualtio/security-headers-checker@v1
  with:
    url: 'https://your-app.com'
    fail-on-missing: ''   # Don't fail, just score

- name: Notify if score is low
  if: ${{ steps.headers.outputs.score < 70 }}
  run: echo "⚠️ Security score is ${{ steps.headers.outputs.score }}/100"
```

---

## Inputs

| Input | Description | Default |
|---|---|---|
| `url` | URL to check | *(required)* |
| `fail-on-missing` | Headers that MUST be present | `Strict-Transport-Security, X-Content-Type-Options, X-Frame-Options` |
| `warn-on-missing` | Headers that trigger a warning | `Content-Security-Policy, Permissions-Policy, Referrer-Policy` |
| `follow-redirects` | Follow HTTP redirects | `true` |
| `timeout` | Request timeout in seconds | `10` |
| `report-file` | Path for JSON report output | *(none)* |

## Outputs

| Output | Description |
|---|---|
| `passed` | `true` if all required headers are present |
| `score` | Security score 0–100 based on headers present |
| `missing-required` | Comma-separated missing required headers |
| `report-path` | Path to JSON report (if `report-file` was set) |

---

## Example Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Security Headers Checker
  URL: https://your-app.com
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HTTP Status: 200

✅  Strict-Transport-Security: max-age=31536000; includeSubDomains
✅  X-Content-Type-Options: nosniff
✅  X-Frame-Options: DENY
⚠️   Content-Security-Policy: MISSING (warning)
❌  Permissions-Policy: MISSING (required)

  Security Score: 78/100
  Present: 7/9 headers
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## License

MIT © 2026 Qualtio Soluciones Digitales, SLU
