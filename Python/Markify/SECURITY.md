# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in Markify, please report it responsibly.

### How to Report

1. **Do NOT** open a public issue for security vulnerabilities
2. Email the maintainer directly at: **steve.wolfe@kcc.com**
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Any suggested fixes (optional)

### What to Expect

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 1 week
- **Resolution Timeline**: Depends on severity
  - Critical: 24-48 hours
  - High: 1 week
  - Medium: 2-4 weeks
  - Low: Next release

### Scope

The following are in scope:
- Code execution vulnerabilities
- Path traversal attacks
- Malicious file handling
- Information disclosure

The following are out of scope:
- Denial of service (this is a desktop app)
- Social engineering attacks
- Issues in dependencies (report to those projects)

## Security Best Practices

When using Markify:
- Only convert documents from trusted sources
- Keep your Python installation updated
- Run the latest version of Markify

## Acknowledgments

We appreciate responsible disclosure and will acknowledge security researchers who help improve Markify's security (with permission).
