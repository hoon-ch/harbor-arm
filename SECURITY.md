# Security Policy

## Reporting a Vulnerability

Do not report suspected image, credential, or supply-chain vulnerabilities in a
public issue before coordinated disclosure.

Use GitHub private vulnerability reporting if it is enabled for this repository.
If it is not enabled, open a public issue that asks the maintainer to enable a
private disclosure channel, but do not include vulnerability details in that
issue. Include the following only in the private report:

- Affected image name and tag
- Image digest
- Reproduction steps
- Scanner output, exploit details, or other evidence
- Whether the issue also affects upstream `goharbor/harbor`

## Supported and Published Images

Security updates are handled for the latest successfully built stable Harbor
release. Older version tags listed in `built_versions.txt` are published build
artifacts, not an ongoing security support matrix, unless a maintainer
explicitly rebuilds a patched historical tag.

The `latest` tag is a convenience pointer. Do not use it as a deployment pin;
pin deployments to an explicit version tag and digest.

## Upstream Harbor Issues

Report Harbor vulnerabilities upstream using the Harbor project's security
process. This repository rebuilds patched releases after upstream publishes
fixed Harbor versions.
