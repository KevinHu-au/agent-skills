# iOS apps (SwiftUI, standalone XCUITest driver)

Load this file in Flow step 4, when the repository has a `*.xcodeproj` or `*.xcworkspace`. It says how the helpers build, install and drive an iOS app in the simulator. It replaces the `ui-start.ps1` contract in `references/react.md`. The app has no `api-start.ps1` of its own: ask the engineer which API this run uses, and mark that recipe `inferred:`. These notes come from general knowledge of the platform. The lines marked checked were checked on one iPad app with Xcode 27.2 and an iOS 26.0 simulator. They are not yet checked on a customer project. Treat each row as a place to look first, not a guarantee. Mark a recipe built only from the unchecked notes `inferred:`.

## Build and install

- Checked: build with `-project "<name>.xcodeproj"`. A `*.xcworkspace` folder that has no `contents.xcworkspacedata` file lists no schemes, and `xcodebuild` says "There are no schemes in workspace", even when the repository's own guide names that workspace. Use the workspace only when it has that file.
- The shared schemes are in `xcshareddata/xcschemes`. Use the scheme the engineer names, and the build configuration that the scheme uses: a scheme's configuration may differ from its name. Checked: the test scheme builds with its own configuration.
- Build into the scratch folder, so the repository stays untouched: `xcodebuild build -project <project> -scheme <scheme> -sdk iphonesimulator -configuration <configuration> -destination "platform=iOS Simulator,id=<device id>" -derivedDataPath <scratch>/dd -clonedSourcePackagesDirPath <scratch>/spm`. Use `build` for the app, not `build-for-testing`: a scheme with no test action can fail the second. Checked: `build-for-testing` worked on a scheme that has a test target. The `build` form is `inferred:`.
- Run `git status --porcelain` in the app repository before and after the build. Checked: once, after a build, a shared scheme file had changed (Xcode moved an attribute) and the cause was not found. A changed tracked file is `blocked`. Report it, and the agent never restores it: the engineer decides.
- Pick the device from `xcrun simctl list devices available`: a device that matches the project's device family (`TARGETED_DEVICE_FAMILY`) on a runtime that exists. Never install a runtime. Boot it with `xcrun simctl boot <device id>` and wait with `xcrun simctl bootstatus <device id> -b`.
- Checked: Xcode 27.2 has no `Simulator.app`, and `open -a Simulator` does nothing. `DeviceHub.app` in Xcode's `Contents/Applications` folder shows the device, and the engineer needs it to sign in. On another Xcode version a Simulator app may exist: `inferred:`.
- Install with `xcrun simctl install <device id> "<scratch>/dd/Build/Products/<configuration>-iphonesimulator/<App>.app"`. An install over an old copy keeps the app's data and its sign-in.
- The bundle identifier is `PRODUCT_BUNDLE_IDENTIFIER` in the project. Do not copy it into a committed file if it names a customer.

## Driver

- The driver is a standalone UI test project in the scratch folder. Generate it with `xcodegen` when that tool is installed: a `bundle.ui-testing` target, platform iOS, and the deployment target and device family of the app. The repository's `project.pbxproj` is never touched, and no test target is added to the repository. When `xcodegen` is not installed, stop with `blocked: xcodegen not found` and print `brew install xcodegen` for the engineer. Never install it, and never write the driver by editing the app's project. Checked: the generated driver ran on a simulator with no signing team.
- Checked: the driver launches the installed app with `XCUIApplication(bundleIdentifier:)`. The app does not have to be hosted by the driver.
- Set `continueAfterFailure = false` in every test. A failed wait then stops the test and saves nothing that looks like a result. Checked: without it, a test saved screenshots of a stuck screen after its wait had failed.
- Pass the evidence folder as `TEST_RUNNER_VERIFY_EVIDENCE_DIR` to `xcodebuild`, and read `VERIFY_EVIDENCE_DIR` in the test. Checked: the test can write PNG and text files there, because the simulator shares the Mac's file system.
- Checked: a list row's own `label` can be empty, and its text sits in child `StaticText` elements. Read `app.debugDescription` to find the identifiers, labels and navigation bar identifiers. Never select by position alone.
- Run one class at a time: `xcodebuild test -project <driver project> -scheme <driver scheme> -only-testing:<target>/<class> -destination "platform=iOS Simulator,id=<device id>" -derivedDataPath <scratch>/dd-driver`.
- Change the app's data only through its own screens, as the engineer would. Never edit the simulator's files, keychain or app container.

## Sign-in

- Never type credentials. The engineer signs in with their own account.
- The driver launches the app and looks for up to 30 seconds at which screen shows first: the login screen, or the signed-in home screen. Checked: both states occur, because an install over an old copy keeps the sign-in.
- With the login screen, the engineer taps the login button and signs in. The driver only waits, up to 600 seconds, until a known home element appears. It taps nothing on the sign-in page. Checked: a Microsoft sign-in opens in a system web view and returns to the app in the simulator.
- Already signed in: say so in the report ("the session was kept from an earlier run"). Never log out.
- A spinner on the login screen is not a result. When the wait ends without a home screen, read the app's log before you report: `xcrun simctl spawn <device id> log show --last 15m --style compact --predicate 'process == "<app process>"'`. Apply the privacy rule in `templates/helpers.md`. Remove every line that has `token`, `bearer`, `authorize`, `client_id`, `code=` or an email address in it before you look at the rest. Look for an `NSURLErrorDomain` code and the host that failed. Report `blocked: sign-in did not complete`, with that host and the error code. Checked: the app showed only a spinner while the log showed a timeout (`-1001`) on the app's token-exchange request.
- A request that fails can also be a network or VPN state of the Mac. Say what you found, and do not name a cause you did not check.

## Doctor

On iOS this section replaces the `doctor.ps1` contract in `templates/helpers.md`. The driver takes the place of the saved current-user response, and there is no container to check and no database-target query to run through an API. Doctor checks these, and prints one line each:

- The simulator is booted, and the app is installed under its bundle identifier.
- The driver sees a known home element, so the app is signed in. It prints that a user is signed in, and never a name.
- A plain request to the API host that the app calls, with no token, only to see whether it answers. Report reachability and the status code. The host name comes from the engineer or from the scheme's configuration keys. Name keys only, never values you were not given.
- The installed app is the one this run built. Print `shasum -a 256` of the executable inside the built `.app` and inside the folder that `xcrun simctl get_app_container <device id> <bundle identifier> app` prints, and require them to match. A failed build or a skipped install leaves an old copy installed. `inferred:`
- Where the screen's data came from. Checked: an app can show an offline badge and a "Syncing" label while a list is on screen, which means the list may be cached local data. Mark every value read from such a screen "cached, not fresh from the API".

## Three-way match on iOS

On iOS the three-way match has two legs, the screen and the database. The iOS app has no browser network log, so the API leg is `unknown:`. It goes under Not verified in the report, and it does not make the result `blocked`. This replaces, for an iOS app only, the rule that a three-way leg for a ticket value that was not done makes the result `blocked`. A ticket value that is not checked on the screen and in the database still does.

## Evidence and privacy

- Screenshots and element trees can hold customer data. Checked: a list screen showed property addresses and IDs. Save them only in the evidence folder, which is outside every repository.
- Never paste a value from a screenshot or a tree into the report, a note, a plan or a commit. Report counts and identifiers, not customer values, unless the engineer asks for a value.
- Filter the lines named in the Sign-in section (`token`, `bearer`, `authorize`, `client_id`, `code=` and email addresses) from the app log before the log reaches a note or the report.
- Never save the app container, the keychain or a response body that holds a person's name.

## ui-start.ps1

Parameters: ticket, scheme, build configuration, and device (a device ID or a name). Builds the app into the scratch folder, boots the simulator if it is not booted, and installs the app. Prints the device name and runtime, the build configuration, the bundle identifier, and `git status --porcelain` before and after the build.

- Rule: it refuses to build when `xcodebuild` lists no schemes for the project, and prints the schemes it did find. It ends with `blocked: <reason>`.
- Rule: it never installs a runtime. When the runtime that the device needs is missing, it prints the command for the engineer and stops with `blocked:`.
- Rule: the project file stays unchanged. It adds no target and edits no scheme. It never runs a UI test that is in the repository.
- It records nothing about the simulator in `state.json`, and `cleanup.ps1` has no process of its own to stop for an iOS app. It never shuts the simulator down: the engineer may be using it.
- A fix command that it prints must not change tracked files.
