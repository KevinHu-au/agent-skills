# External systems

An external system is anything outside this repository that the application calls, or that calls the application: a message broker, an integration platform such as BizTalk, an identity provider, a payment service, another team's API. The engineer wants to know two things for each: which endpoints and services depend on it, and which features depend on it.

## Method

1. **Find the integration code.** Look for client or adapter classes, generated service references, queue or topic senders and receivers, SDK packages, and configuration keys that hold an address or a queue name (name the key, never the value). `dotnet.md` lists where these live in a .NET project. `ios.md` (section External systems) lists where they live in an iOS project. `react.md` (section External systems) lists where they live in a React project.
2. **Trace up to the callers.** From each integration call, find the code that calls it. Then follow those callers up to an entry point: a controller endpoint, a UI handler, or a background job (hosted service, scheduler, queue consumer). Cite `path:line` at each hop.
3. **Map to use cases.** Match each endpoint and job to a use case in the brief. A feature depends on the system when its use case reaches an integration call.
4. **Find the inbound side.** Look for endpoints that an outside system calls: unusual authentication (API key, client certificate, IP allow list), unusual message formats (SOAP, XML, EDI, webhooks with signatures), and routes no user screen uses.
5. **List what does not depend on it.** An endpoint that never reaches the system is a fact too. Say so.

## Limits

- A call hidden behind dependency injection, an event or a queue may not show in a plain search. Mark the link `inferred:` and say which hop is missing.
- If you cannot detect inbound calls, ask the engineer. Do not claim there are none.
- The other side of the boundary is not in this repository. Write `unknown: ask the <system> owner` for anything you cannot read here.
- A part that lives in another repository is `unknown:` plus the path or name to ask for.
- Open a configuration file to find key names and addresses. Never copy a secret value, and never write one into the pack. A committed secret is itself a finding: name the key and the file.

## Record for each system

- **Name** and a one-line description.
- **Owner:** the team or person. `unknown: ask the <system> owner` if no document says.
- **Direction:** outbound (we call it), inbound (it calls us), or both.
- **Protocol and endpoint names:** for example HTTP with the operations used, a queue name, a SOAP action. Configuration key names only.
- **Data crossing the boundary:** the main messages or entities, in each direction.
- **Our endpoints, services and jobs that depend on it:** each with `path:line`. Mark hops you could not follow `inferred:`.
- **Features and use cases that depend on it:** what fails for a user when it is down.
- **Failure behaviour:** timeouts, retries, queues, what the user sees. If the code shows none, say so.
- **Local test possible:** a stub, a sandbox, a test environment, or none. `unknown:` if not found.
- **Sources:** the files the record came from.

This record feeds the `External systems` section of the brief and the `External systems and owners` table in the project contract.
