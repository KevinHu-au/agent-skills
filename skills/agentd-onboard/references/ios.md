# iOS projects (SwiftUI)

Load this file for an iOS (SwiftUI) project (the stack signals in `SKILL.md`). A `Package.swift` alone can also be a server or command-line package. It says where a SwiftUI app keeps the things the explorers look for. Treat each row as a place to look first, not a guarantee. These notes come from general knowledge of the platform. They are not yet checked on a customer project. The test commands and flags below were run on Xcode 26.0.1 against a small synthetic Swift package. Not run against an app-hosted test target.

## Runtime and layout

| Fact | Where to look |
|---|---|
| Deployment target and devices | `IPHONEOS_DEPLOYMENT_TARGET` and `TARGETED_DEVICE_FAMILY` in `project.pbxproj` or `*.xcconfig`; `Package.swift` platforms. A README often disagrees. The project file wins. |
| Targets, schemes and environments | `*.xcscheme` files and `project.pbxproj` (shared schemes are in `xcshareddata/xcschemes`; `xcuserdata` is per user); build configurations; one `Info-<env>.plist` or `*.xcconfig` per environment |
| App entry | The `@main` type that conforms to `App`; an `AppDelegate` attached with `UIApplicationDelegateAdaptor` |
| Dependencies | Swift Package Manager: `Package.resolved` and the package references in `project.pbxproj`. Also `Podfile.lock` (CocoaPods) and `Cartfile.resolved` (Carthage) on older projects. |
| Configuration | `Info.plist` files, `*.xcconfig`, `*.entitlements`, `GoogleService-Info.plist`. Name keys only. |

## Behaviour

| Fact | Where to look |
|---|---|
| Screens | Types that conform to `View`; `NavigationStack`, `NavigationSplitView`, `TabView`, `.sheet`, `.fullScreenCover`; `.navigationDestination(for:)`. UIKit screens appear as `UIViewControllerRepresentable` or storyboards. |
| Navigation state | A router or coordinator type; `NavigationPath`; an auth-state type that decides the first screen |
| State and view models | `@Observable` (iOS 17+) or `ObservableObject` with `@Published` and `@StateObject`; `@Environment`, `@EnvironmentObject`. Note which style each screen uses. |
| Data loading | `.task` loaders, `@Query`, and service types that fetch or read the local store |
| Calculations | Services and view-model computed properties that compute a value before it is shown |
| Business rules | Service, validation and extension types that view models call, not the views |
| Permissions and roles | Claims in the sign-in token; code that hides or disables a control by role. The server is the real gate: `unknown: ask the API owner`. |
| Background work | `BGTaskScheduler`, background `URLSession`, push handlers in the app delegate, `Task` started from `.task` or `.onAppear` |

## Data

| Fact | Where to look |
|---|---|
| Local store | SwiftData `@Model`, `ModelContainer`, `@Query`; Core Data `*.xcdatamodeld`; files in the app sandbox; `UserDefaults`; Keychain |
| Schema changes | `VersionedSchema` and `SchemaMigrationPlan` (SwiftData); model versions and mapping models (Core Data). A non-trivial schema change without a plan can fail to open the store on upgrade. |
| Relationships | `@Relationship(deleteRule:)`. A cascade rule deletes children with the parent. |
| Wire shapes | `Codable` types, DTO types and the mapping to the local model; `CodingKeys` and key decoding strategies |
| Generated files | OpenAPI or other generated clients, SwiftGen output, `R.generated.swift`. Find the command that regenerates each. |

## External systems

| Fact | Where to look |
|---|---|
| HTTP | `URLSession` wrappers, a request handler type, Alamofire; the base address in the environment plist (name the key, never the value) |
| Sign-in | MSAL, `ASWebAuthenticationSession`, Sign in with Apple, Keychain token storage, token refresh code |
| SDKs | Crash and analytics SDKs, MetricKit subscribers, push notification set-up |
| Build and release | `azure-pipelines.yml`, `ci.yml`, `fastlane/Fastfile`, signing and provisioning set-up. Name the files, never the certificates. |
| Inbound | URL schemes, universal links (`apple-app-site-association`), push payloads, app extensions and widgets |

## Tests

| Fact | Where to look |
|---|---|
| Test targets | `*Tests` and `*UITests` targets; `*.xctestplan`; XCTest (`XCTestCase`, `func test...`) and Swift Testing (`@Test`, `@Suite`) |
| Run | `xcodebuild test` with `-workspace` or `-project`, `-scheme` and a simulator `-destination`. The pipeline file shows the exact destination. Read the command from the pipeline file. Do not run a test here: a test run boots a simulator and can launch the app, which `safe-checks.md` forbids. |
| Build | A build writes to Xcode's default DerivedData folder in the user's Library folder unless `-derivedDataPath` is given, and it fetches the Swift packages. Say so in the confirmation. |
| Filters | `-only-testing:` and `-skip-testing:`. A filter that names no test method exits 0 with `Executed 0 tests`. List the tests instead of running them: `xcodebuild test -enumerate-tests` on Xcode 15 and later. It builds the scheme first and needs a destination. Each ID ends in `()`, for example `Target/Suite/name()`. For a test target with no host app, an iOS simulator destination listed the tests and left the simulator shut down. A test target is hosted in the app when `TEST_HOST` (and `BUNDLE_LOADER`) is set in `project.pbxproj`. With no `TEST_HOST`, it is a logic test. For a hosted target, listing may launch the app, so the count stays `unknown:`. Record the count from the list. |
| UI tests | They drive a simulator and may need a signed-in account or a network service. Never run them from this skill. |
| Mocks | A `Mocks` folder or protocol-based fakes in the test target. They show which services sit behind protocols. |
