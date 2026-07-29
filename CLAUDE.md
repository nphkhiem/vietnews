# VietNews (Thông Tấn Xã)

Centralized iOS news reader aggregating multiple sources (NYT, BBC, VNExpress, Eurogamer, Substack, generic RSS).

## Stack
- Swift 5.9, iOS 16.0+, UIKit `SceneDelegate` + SwiftUI views
- Package manager: SPM via XcodeGen (`project.yml`)
- Dependencies: [FeedKit](https://github.com/nmdias/FeedKit) (RSS/Atom parsing), [Factory](https://github.com/hmlongco/Factory) (DI)

## Project generation
`.xcodeproj` is gitignored — it is regenerated from `project.yml`. Never hand-edit the pbxproj.

```bash
xcodegen generate          # regenerate VietNews.xcodeproj after editing project.yml
open VietNews.xcodeproj    # open in Xcode
```

If XcodeGen is missing: `brew install xcodegen`.

## Secrets
`Secrets.xcconfig` is gitignored. Bootstrap:

```bash
cp Secrets.xcconfig.example Secrets.xcconfig
# then set NYT_API_KEY (no quotes — xcconfig does not strip them)
```

`NYT_API_KEY` is injected into `Info.plist` via `project.yml`. Get a key from https://developer.nytimes.com (enable Top Stories API).

Gitignoring it protects the repository, not the key. It ships inside the app and is readable from any distributed build, so treat it as public and use a free key you are willing to have exposed.

## Build & test (CLI)
```bash
# Build
xcodebuild -project VietNews.xcodeproj -scheme VietNews \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Unit + UI tests (scheme runs both bundles)
xcodebuild -project VietNews.xcodeproj -scheme VietNews \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Architecture
Clean-ish layering under `VietNews/`. Dependencies flow inward: `Presentation → Domain ← Data`, with `Infrastructure` wiring cross-cutting concerns.

| Layer | Contents |
|---|---|
| `App/` | `AppDelegate`, `SceneDelegate`, `RootView`, UI-test support hooks |
| `Domain/` | Pure models (`Article`, `NewsSource`, `NewsCategory`, `Language`, `NewsError`), repository protocols, use cases (`FetchNewsUseCase`, `RefreshNewsUseCase`) |
| `Data/` | `DTOs/` (per-provider decode types), `Network/` (`NetworkService`, `RSSParser`, HTML helpers), `Sources/` (per-provider `NewsSourceAdapter`s), `Repositories/` (`RemoteArticleRepository`, `DiskCacheRepository`) |
| `Infrastructure/` | `DI/Container+Registrations.swift` (Factory), `Storage/` (`UserPreferences`, `NetworkMonitor`), `Timer/AutoRefreshScheduler` |
| `Presentation/` | `NewsFeed/` and `Settings/` SwiftUI views + view models, shared `Components/` |

### Conventions
- Adding a new source: create `Data/Sources/<Name>Source.swift` conforming to `NewsSourceAdapter`, add its DTO under `Data/DTOs/` if needed, register it in `Container+Registrations.swift`, and extend `NewsSource` in `Domain/Models/`.
- DI: resolve via `Container.shared` (Factory). Register in `Infrastructure/DI/Container+Registrations.swift` — do not scatter registrations.
- Keep `Domain/` free of Foundation networking / UIKit / SwiftUI imports.

## Tests
- `VietNewsTests/` mirrors production layering (`Domain`, `Data`, `Infrastructure`, `Presentation`, `Integration`) plus `Fixtures/` and `Helpers/`.
- `VietNewsUITests/` — smoke + feed flows.
- Add tests for new use cases, adapters, and view models. Prefer fixtures under `VietNewsTests/Fixtures/` over inline JSON blobs.

## Self-review gate
Before declaring done:
1. `xcodegen generate` if `project.yml` changed.
2. `xcodebuild ... build` — zero new warnings.
3. `xcodebuild ... test` — all suites green.
4. No `TODO`/`FIXME`, no dead code, no debug prints, no committed secrets.
