# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-22

### Added

- Initial release of EndpointVault Flutter SDK
- `EndpointVault` client for SDK initialization and event capture
- `EndpointVaultInterceptor` for automatic Dio request capture
- AES-256 encryption service for payload encryption
- Automatic redaction of sensitive headers and body fields
- Configurable redaction rules with regex pattern support
- Offline queue for storing events when network unavailable
- Device-side replay handler for re-executing failed requests
- Extension methods on Dio `Options` for marking critical requests
- Support for custom server URLs (self-hosted deployments)
- Environment and app version tracking for regression analysis
- Event stream for real-time monitoring of captured events

### Security

- Client-side encryption before any data leaves the device
- Default redaction of Authorization headers, tokens, and passwords
- Secure key derivation using SHA-256 for non-32-byte keys
