# iOS projects (SwiftUI)

Where to look in an iOS app. These notes come from general knowledge of the platform. They are not yet checked on a customer project. The test commands and flags below were run on Xcode 26.0.1 against a small synthetic Swift package. Not run against an app-hosted test target.

## Run and count tests

- Run one test class or method: `xcodebuild test -workspace <name>.xcworkspace -scheme <scheme> -destination "<destination>" -only-testing:"<Target>/<Class>/<method>"`. A Swift Testing ID must end in `()`, for example `Target/Suite/name()`, or the run executes zero tests. An XCTest method name works without it. Use `-project` when there is no workspace. Copy the destination from the pipeline file.
- Run only logic tests that need no network, account or configured service. A test hosted in the app launches the app, so it needs the contract to allow it. A test target is hosted in the app when `TEST_HOST` (and `BUNDLE_LOADER`) is set in `project.pbxproj`. With no `TEST_HOST`, it is a logic test. Put the command on the run plan.
- Send build output to the scratch folder with `-derivedDataPath <scratch>/DerivedData`. Otherwise Xcode writes to its default DerivedData folder in the user's Library folder, outside the repository. A fresh DerivedData path fetches the Swift packages again over the network. The package cache and the app installed on the simulator stay after the scratch folder is removed. Say so in the run plan. If signing blocks the build, add `CODE_SIGNING_ALLOWED=NO` and say so. Without signing, keychain and app-group code can fail. Such a failure is not evidence.
- Never run UI tests from this skill, even when the contract allows starting the app. They may need a signed-in account or a network service.
- A filter that names no test method exits 0 and prints `Executed 0 tests`. A filter that names a missing test target fails with exit 70. Check the total in the output and compare it with the count in the Commands heading of the contract.
- A simulator run needs the simulator runtime named in the destination. If it is missing, say so and give the engineer the command. Do not install it.

## Bug candidates

- State and main thread: UI state changed off the main actor, a missing `@MainActor`, a stale `@State` copy of a model value, a view that does not observe the type it reads.
- Task lifetime: a `Task` that nobody cancels, work started in `.task` or `.onAppear` that runs twice, a result that arrives after the screen has gone.
- Concurrency: shared mutable state outside an actor, a `Sendable` warning that was silenced, an actor call that suspends so the state differs after the `await`.
- Optionals and decoding: a forced unwrap, `try?` that hides an error, a DTO that decodes with a default and hides a missing field. A removed or renamed non-optional field, a changed type, or a new enum value can fail decoding for the whole response.
- Time and locale: `Date()` against a fixed time zone, `Calendar` and `DateFormatter` set to the device locale, 12-hour and 24-hour formats, number formats.
- Local store: a SwiftData or Core Data save that never runs, a relationship delete rule that removes more than intended, a model changed with no migration, a context used on the wrong thread.
- Sign-in: token expiry and silent refresh, a token cached across accounts, Keychain data that survives an app delete.
- App lifecycle: scene phase changes, a push or deep link that arrives while the app is closed, an upgrade from an older installed version.
- Environment: the Debug, Test and Production schemes read different plist files. Name the key, never the value.
- Device: iPad and iPhone layouts differ, Dynamic Type, dark mode, orientation, and the iOS version. An API available on a newer iOS crashes an older device. Look at the deployment target.

## Crash reports (`.ips`)

The engineer sends the report: from Xcode Organizer, from the Crashlytics or Sentry console, or from a device. Install nothing. Read the file as text. A report can hold a device name, an account and paths: do not repeat them. These steps come from general knowledge. They were not run.

- A crash `.ips` file from iOS 15 or later holds two JSON documents: a one-line header, then the body. Parse them one at a time. In the body read: the app version and build, the OS version, the device model, the exception type and codes, the crashed thread, and its frames (`imageIndex` and `imageOffset` for each). `usedImages[imageIndex]` gives the image's `base` (its load address), its `name` and its `uuid`. A Crashlytics or Sentry export is not an `.ips` file and has its own shape: read its stack and its version fields, and ask for the raw `.ips` if you need the offsets.
- A frame shows a name only when the report is symbolicated. Otherwise it needs the dSYM of the same build. Check that the UUID in the report matches `dwarfdump --uuid <App.app.dSYM>`. A dSYM from another build gives wrong names. If it is missing, ask for it, from the build pipeline or from App Store Connect.
- To symbolicate a frame, the engineer runs `atos -arch arm64 -o <App.app.dSYM>/Contents/Resources/DWARF/<App> -l <load address of the image> <frame address>`. The load address is `usedImages[imageIndex].base`. The frame address is that base plus `imageOffset`.
- Write down the exception type, the top app frames with `path:line` once symbolicated, the app and OS versions, and whether the crash needs a state, such as a signed-in user or an upgrade from an older version.
- **Tier:** a crash report shows where the app stopped. It is `supported` until a local run, a test or a simulator run built from the same inputs produces the crash.

## Data candidates

- The data lives on the device or on a server. Find which: the local store, the sync code that writes it, and the API it syncs with.
- Find the writers of a local model: the sync service, the view models that edit it, import code, and migration code. Find the readers too.
- Server rows written by the app: find the request that writes them, then the server's handler. The server code is often in another repository: `unknown: ask the <system> owner`, or ask the engineer for its path and read it as SKILL.md, Rules, says.
- Do not read a customer's device or a production store. Reproduce with a synthetic store in the simulator only if the contract's Commands or Verify heading allows starting the app. Otherwise mark the fact `unknown:` and give the engineer the steps. A store copied from a device holds personal data.
- Logs can hold personal data. Read only what the ticket needs, and quote none of it.

## Performance candidates

- Measure a Release build, on a real device if you can. A Debug build and the simulator are not representative. The simulator uses the Mac's CPU and memory.
- Instruments: Time Profiler for CPU, Allocations and Leaks for memory, SwiftUI for view body re-evaluation, the Hangs instrument for main thread stalls, App Launch for launch time, the Network template for requests. A trace launches the app. Start one only if the contract allows starting the app. Otherwise give the engineer the steps.
- MetricKit payloads and the crash and hang reports in the project's analytics show field data. Ask for them.
- Slow lists: a `ForEach` over unstable IDs, an `Identifiable` ID made from a new `UUID()` on each render, heavy work in a view `body`, images decoded at full size on the main thread, a `@Query` without a predicate or fetch limit.
- N+1: a request or a fetch per row. The cost is the request count. Count the requests in the Instruments Network template or in the project's own request logging.
- Sync: the full set is downloaded on each run, or items are saved one at a time instead of in a batch.
- Launch time: work done before the first screen, such as store set-up, sign-in and SDK start-up.
