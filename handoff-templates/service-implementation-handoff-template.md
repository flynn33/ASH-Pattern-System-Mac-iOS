> Historical reference retained from the pre-SDK Apple baseline. For SDK 1.0.0, current semantic authority is ASH-Pattern-System 1.0.0-rc.3 at 50d7e5ab88932a4a967ffc2c83bd18fae45b73c8. Current public-contract decisions override conflicting retained prose; see repository-root docs/sdk-authority-and-conformance.md.

# Service Target Boundary

## Status

Not applicable to the Mac/iOS edition.

## Reason

This repository targets Apple-platform Swift package work for macOS and iOS. It does not define, host, package, test, or release a service or backend runtime.

## Mac/iOS Implication

Service hosting, API surfaces, container images, server deployment, request concurrency, service observability, and service secret management are outside the release scope of this repository.

The active target checklists are `desktop-implementation-handoff-template.md` for macOS and `mobile-implementation-handoff-template.md` for iOS.
