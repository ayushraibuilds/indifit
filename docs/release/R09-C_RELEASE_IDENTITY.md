# R09-C release identity

Status: implemented for native source validation; signed store artifacts remain
an R09-D gate.

## Frozen public V1 identity

| Field | Value |
| --- | --- |
| Product name | IndiFit |
| Android application ID | `com.indifit.indifit` |
| iOS bundle identifier | `com.indifit.indifit` |
| Version | `1.0.0` |
| Build number | `1` |
| Brand field | `#060A12` |
| Brand accent | `#34D399` / `#5EEAD4` |

The application/package identifier is a permanent store identity. Development
variants must use a `.dev` suffix and must never be used to create public
distribution artifacts.

## Signing ownership

- Android release builds fail closed unless an ignored `android/key.properties`
  points to the owner-controlled upload keystore. The committed
  `android/key.properties.example` is the credential-free template.
- iOS uses automatic signing with the owner-selected development team already
  recorded in the Xcode project. R09-D must validate the App Store archive and
  provisioning result from the owner account.
- No keystore, password, provisioning profile, or exported signing credential is
  committed to source control.

## Asset behavior

- iOS receives an opaque App Store icon at every required catalog size.
- Android receives legacy density icons plus a native adaptive/round icon with a
  separate transparent foreground and Android 13 monochrome mask.
- Android 12+ and legacy Android launches use the same midnight field and emblem.
- iOS uses a centered, fixed-size transparent emblem on the same midnight field.

## R09-D handoff

Before store submission, produce and install the signed Android App Bundle and
iOS archive, then verify displayed identity, signing certificate/team,
application identifiers, version/build values, adaptive masks, and launch
transition on physical devices.

The R09-C unsigned physical-device build passed. It also reported that the
current transitive Google ML Kit barcode packages do not support the arm64
architecture required by Apple Silicon iOS 26+ simulators. R09-D should retest
the chosen simulator/device matrix and decide whether a compatible barcode
dependency update is required; this warning does not justify a broad dependency
upgrade inside R09-C.
