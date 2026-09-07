# Release Process

MacTermX ships via GitHub Releases, ad-hoc signed — the same approach as
the author's other macOS apps (HG4MAC, ROMForge, DiskCenter, etc.). No
CI/CD pipeline does this automatically; it's a short manual sequence run
locally before tagging a release.

## Prerequisites

- `xcodegen` (regenerates `MacTermX.xcodeproj` from `project.yml`)
- `gh` (GitHub CLI), authenticated
- The Xcode Metal Toolchain component installed (`xcodebuild -downloadComponent MetalToolchain`) —
  SwiftTerm bundles Metal shaders for its own (unused) AppKit renderer, and the app target won't
  build without it. One-time setup per machine, not per release.

## Steps

1. **Bump the version** in `project.yml` — `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION` if
   the build number should change too).
2. **Update `CHANGELOG.md`** — move the relevant `[Unreleased]` entries under a new
   `## [x.y.z] - YYYY-MM-DD` heading.
3. **Regenerate and build:**
   ```bash
   xcodegen generate
   xcodebuild -project MacTermX.xcodeproj -scheme MacTermX -configuration Release \
     -skipPackagePluginValidation build
   ```
   `-skipPackagePluginValidation` is required — SwiftTerm ships a build-info Swift Package
   plugin that Xcode otherwise refuses to run without interactive approval.
4. **Smoke-test the build**: launch it from `DerivedData`, confirm it opens, discovers ports,
   and connects to real hardware if any is attached. Run `swift test` in `MacTermXCore/` too —
   both should be green before tagging anything.
5. **Zip the built app**, matching the convention used across the author's other apps:
   ```bash
   ditto -c -k --sequesterRsrc --keepParent \
     ".../Build/Products/Release/MacTermX.app" "MacTermX-v<version>.zip"
   ```
6. **Commit, tag, and push:**
   ```bash
   git add -A
   git commit -m "Release v<version>"
   git tag v<version>
   git push && git push --tags
   ```
7. **Create the GitHub Release**, attaching the zip and the relevant `CHANGELOG.md` section as
   release notes:
   ```bash
   gh release create v<version> "MacTermX-v<version>.zip" \
     --title "MacTermX v<version>" --notes-file <(sed -n '/## \[<version>\]/,/## \[/p' CHANGELOG.md)
   ```

## Signing

The app is **ad-hoc signed** ("Sign to Run Locally", `CODE_SIGN_IDENTITY = "-"` in
`project.yml`) — a real ad-hoc signature (`codesign -s -`), not merely
linker-signed. That's enough for the app to run normally and register with system
services; what it does *not* do is satisfy Gatekeeper's "identified developer" check, so a
downloader gets the "Apple could not verify..." prompt on first launch and has to
right-click → Open (or `xattr -d com.apple.quarantine` it) once. This is a known, accepted
tradeoff of not (yet) paying for a Developer ID — see the README's "Distribution" section.

## Future: Developer ID + notarization

Once there's a paid Apple Developer Program account:

1. Set `CODE_SIGN_IDENTITY` to the Developer ID Application certificate's name and
   `CODE_SIGN_STYLE: Automatic` (or manual with an explicit team ID) in `project.yml`.
2. `ENABLE_HARDENED_RUNTIME` should switch to `YES` — required for notarization.
3. After building, notarize with `xcrun notarytool submit` and staple the ticket with
   `xcrun stapler staple` before zipping.
4. Verify with `spctl -a -vv MacTermX.app` — should report "accepted, source=Notarized
   Developer ID" instead of today's "source=Unnotarized Developer ID" (or similar for
   ad-hoc).

## Future: Homebrew Cask

Once there's at least one tagged GitHub release to point at, a Cask can be added to
`homebrew-cask` (or a personal tap first, e.g. `jensyleo/homebrew-tap`) pointing at the
release zip's URL and SHA-256. Not worth setting up before the first real release exists.
