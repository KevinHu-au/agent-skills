# iOS projects (SwiftUI)

Where to look in an iOS app. These notes come from general knowledge of the platform. They are not yet checked on a customer project. The test commands and flags below were run on Xcode 26.0.1 against a small synthetic Swift package. Not run against an app-hosted test target.

## The installed app

- An old build stays installed on devices for months, and users may not update. A change to the server, the wire shape or the sync protocol meets every shipped version. Look for a minimum-version check and a forced-update screen.
- A change inside the app ships only with a new build. Without a feature flag or remote configuration there is no hot fix. A bad release needs a new build and App Store review, so count the delay as cost.
- Do not start the app unless the contract allows it. A break stays `supported` unless a run shows the shape that the client reads. A logic test that is not hosted in the app can be a proof. See `Run and count tests`.

## Wire shapes

- Names come from `Codable` and `CodingKeys`. Check the key decoding strategy on the `JSONDecoder` (`convertFromSnakeCase` and similar). A property rename changes the wire name unless a `CodingKeys` entry pins it.
- A DTO type is mapped to a local model. A change to either side needs both to change. Find the mapping code.
- Decoding fails for the whole response when a non-optional field is missing, a type changes, or an enum gets a new value. Check whether each property is `Optional`, and look for `decodeIfPresent`, defaults and enums with an unknown case.
- Dates: `Date` decoding strategy (`iso8601`, custom formatter, seconds or milliseconds). Locale and time zone change what a formatter reads.
- Generated clients (OpenAPI and similar) may need a regenerate. Find the command in the contract.

## Data

- SwiftData: a changed `@Model` needs a `VersionedSchema` and a `SchemaMigrationPlan`. Without them an upgrade can fail to open the store or lose data. Read the migration plan before you trust it.
- Core Data: a changed model needs a new model version and a mapping. Check lightweight against custom migration.
- A property rename or a type change is a different migration from an added property with a default. A rename needs `@Attribute(originalName:)` in SwiftData, or a renaming identifier in Core Data.
- `@Relationship(deleteRule: .cascade)` deletes the children with the parent. Check what else holds the child.
- Readers of a property: search the code for the name. In Core Data also search `NSPredicate(format:)`, `NSSortDescriptor(key:)`, `@FetchRequest` sort keys and `value(forKey:)`. These are strings that the compiler does not check. SwiftData `#Predicate`, `@Query` and `FetchDescriptor` use checked key paths, but a renamed property still compiles and changes the stored name unless `@Attribute(originalName:)` pins it.
- `UserDefaults` and Keychain keys are strings that other code reads. Search for the key as a string. Keychain data survives an app delete. A renamed `@AppStorage` key (it is a `UserDefaults` key) or `@SceneStorage` key resets the user's setting or the restored scene without an error.
- A `Codable` value saved as JSON or a property list (in `UserDefaults`, a file or an app group container) follows `CodingKeys` and the shape of the type. New code reading old data: a new non-optional field or a changed type fails to decode, and a removed field is ignored, so its old data is dropped without an error. Old code reading new data (an old build, or an app extension) fails when a field it requires is gone. Look for a stored version number and a fallback.
- `NSKeyedArchiver` data stores the class name. A class that is renamed, or moved to another module, stops old archives from decoding, unless `@objc(Name)` or `NSKeyedUnarchiver.setClass(_:forClassName:)` maps the old name. With secure coding on, the new class must also be in `allowedClasses`.
- A stored `RawRepresentable` value (an enum raw value, a status string) is compared by other code. A renamed case or a renumbered value changes the meaning of old data.
- A renamed widget `kind` string removes the widget from the user's home screen.
- A renamed or removed App Intent breaks the shortcuts that users built.
- Task and notification identifiers: a `BGTaskScheduler` identifier (it must also be listed in `Info.plist`), and a pending notification request with its identifier and `userInfo`. A renamed identifier or a changed payload leaves the already-scheduled items with no handler.
- CloudKit record types and fields, and `NSUbiquitousKeyValueStore` keys, are shared with devices that still run an old build. A schema that has shipped cannot be rolled back.

## Indirection

- SwiftUI environment: services are injected with `.environment(...)` or `.environmentObject(...)`. A missing `@EnvironmentObject` or `@Environment(<Type>.self)` object crashes at run time when a view reads it, not at build time.
- Protocols and mocks: a protocol change must change the real type and the test mocks.
- Notifications and observers: `NotificationCenter`, `.onChange`, `.onReceive` and `.task(id:)` react to a change without a call site.
- Deep links and push payloads: URL schemes, universal links and notification handlers call code by a string route.
- App extensions, widgets and App Intents read the same shared container and the same types.
- Actors and `@MainActor`: moving code across an isolation boundary changes where it runs.

## Configuration

- One `Info-<env>.plist` or `*.xcconfig` for each scheme, plus build settings and entitlements. A key added to one file and not the others breaks one environment only. Name the key, never the value.
- Feature flags and remote configuration, if the app has them.
- Signing, provisioning and capabilities (push, keychain groups, app groups) are in the project file and the entitlements. A capability change needs the Apple developer account.

## Libraries

- Pinned versions are in `Package.resolved`, `Podfile.lock` or the project file. Read the source of the library at that version. A major version can change behaviour.
- The deployment target limits which system APIs the code may call. A raised target drops older devices. A lowered target needs availability checks.

## Authorisation

- Role checks in the app only hide controls. Find where the server enforces the rule, and whether the change moves it.
- Sign-in scopes, token lifetime and silent refresh: check that a changed scope or claim does not log out users.

## Run and count tests

- A filter that names no test method exits 0 and prints `Executed 0 tests`. A Swift Testing ID must end in `()`, for example `Target/Suite/name()`, or the run executes zero tests. A filter that names a missing test target fails with exit 70. Check the total in the output and compare it with the count in the Commands heading of the contract. Use `-workspace` or `-project` to match the project, and `-only-testing:` to pick the test.
- Run only logic tests that need no network, account or configured service. A test hosted in the app launches the app, so it needs the contract to allow it. A test target is hosted in the app when `TEST_HOST` (and `BUNDLE_LOADER`) is set in `project.pbxproj`. With no `TEST_HOST`, it is a logic test. Put the command on the run plan.
- Send build output to the scratch folder with `-derivedDataPath <scratch>/DerivedData`. A fresh DerivedData path fetches the Swift packages again over the network. The package cache and the app installed on the simulator stay after the scratch folder is removed. Say so in the run plan. If signing blocks the build, add `CODE_SIGNING_ALLOWED=NO` and say so. Without signing, keychain and app-group code can fail. Such a failure is not evidence.
- A simulator test needs the runtime named in the pipeline's destination. If it is missing, the proof stays `unknown:` and the engineer gets the command.
- Never run UI tests from this skill, even when the contract allows starting the app. They may need a signed-in account or a network service.
