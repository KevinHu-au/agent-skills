# iOS apps (SwiftUI)

Load this file for an iOS (SwiftUI) project (the stack signals in `SKILL.md`). Treat each row as a place
to look first, not a guarantee. The API behind the app is often in another
repository: the trail then stops at the HTTP call, as `SKILL.md` says.

## Detect

The stack signals in `SKILL.md` decide when to load this file. These lines say what to look for once it is loaded.

- A `*.xcodeproj` or `*.xcworkspace`; an `@main` type that conforms to `App`.
- Swift files that `import SwiftUI`; `*.xcdatamodeld` (Core Data) or `@Model` types (SwiftData).

## Layers

1. View: the SwiftUI `View` that shows the figure or status.
2. View model or context: an `@Observable` or `ObservableObject` type the view reads, or a shared context object in
   the environment.
3. Service: the type the view model calls to load, save or sync data.
4. Request handler: the type that builds and sends the HTTP request (`URLSession`). This is the API boundary.
5. API: the endpoint the request names. Often in another repository.
6. Local store: SwiftData or Core Data, when the value comes from the device and not from the API.

## Where to look

| Layer | Where to look |
|---|---|
| View | Types that conform to `View`; `NavigationStack`, `TabView`, `.sheet`; the text or label the engineer named |
| View model or context | `@Observable`, `ObservableObject` with `@Published`, `@Environment`, `@EnvironmentObject` |
| Service | `Services/` folders; types the view model holds; `async` functions that call the request handler |
| Request handler | `URLSession` wrappers; a request or network type; the base address key in the environment plist (name the key only) |
| Local store | SwiftData `@Model`, `ModelContainer`, `@Query`; Core Data `*.xcdatamodeld`; `UserDefaults` |
| Status values | An `enum` of states (often `String` raw values that the screen shows); every place that assigns each case |
| Retry and sync | Retry helpers (a wrapper or loop with a delay), sync or queue services, `BGTaskScheduler`, background `URLSession`. Note the retry count, the delay, and which errors end the retries. |
| Wire shapes | `Codable` types, `CodingKeys`, and the mapping to the local model |
