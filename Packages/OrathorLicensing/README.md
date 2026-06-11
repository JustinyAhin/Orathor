# OrathorLicensing

Open-source stub of Orathor's licensing module. Builds from this repo are always licensed — dictation is never gated.

Official binaries distributed by the maintainer swap this package's contents for a closed implementation (trial + license-key enforcement backed by Polar.sh) at release time. The swap is by directory content only, so the Xcode project is identical either way.

## API contract

Both implementations expose the same public surface:

- `LicenseState` — `licensed(email:)`, `trialing(daysLeft:)`, `trialExpired`, `licenseInvalid(reason:)`
- `LicenseError` — `invalidKey`, `activationLimitReached`, `network(String)`, `notActivated`
- `LicenseManager` (`@MainActor @Observable` final class):
  - `state: LicenseState`
  - `isGated: Bool` — `false` in this stub; drives whether license UI is shown
  - `canDictate: Bool` — `true` when licensed or trialing
  - `maskedLicenseKey: String?`
  - `init()` — synchronous, no network
  - `refresh() async`
  - `activate(key:) async throws(LicenseError)`
  - `deactivate() async throws(LicenseError)`

Changes to this surface must be mirrored in the private implementation.
