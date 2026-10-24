# React frontends

Where to look in a React web app: a `package.json` in the repository, or in a workspace folder, lists `react-dom` under `dependencies`. A React Native app does not use `react-dom`. These notes come from general knowledge of the platform. They are not yet checked on a customer project. The test flags below were not run.

## The shipped bundle

- A user's browser keeps the old bundle until it reloads. A tab left open runs old code against the new API. A change to the API, the wire shape or the auth flow meets every loaded version. Look for a version check or a forced reload.
- A CDN or browser cache can serve an old `index.html` or old chunks. Check the cache headers and the hosting configuration. Hashed file names help only if `index.html` is not cached.
- A Next.js or Remix app also runs React on the server. A change to a server component, a route handler or an API route ships with the server, not the bundle. Check the `'use client'` boundary, the `NEXT_PUBLIC_*` keys that are baked into the client bundle, and the page and data caches (`revalidate`, the `fetch` cache). A cached page can serve old data after the change.
- A change inside the app ships with a new build and deploy. Without a feature flag there is no switch to turn it off. A bad release needs a rollback or a new deploy, so count that time as cost.
- Do not start the app unless the contract allows it. A break stays `supported` unless a run shows the shape that the client reads. A unit or component test that needs no browser can be a proof. See `Run and count tests`.

## Wire shapes

- TypeScript types are not checked at run time. A renamed, removed or null field compiles and then fails in the browser. Search for the field name as a string too, in `zod` schemas, mocks and test data.
- A generated client (NSwag, OpenAPI generator) can go out of date against the API. Find the regenerate command in the contract. A regenerate changes many files, so read the diff.
- The response is often mapped to a view model. A change to either side needs both to change. Find the mapping code.
- Dates: strings parsed with `new Date(...)`, time zones, seconds or milliseconds. Enum values: a switch with no default branch breaks on a new value.

## Indirection

- Props and components: a changed prop type or name reaches every parent. A component used by many pages has many callers. Search for the component name and its import path.
- Context and stores: a change to a context value or a store shape reaches every `useContext`, selector and `useQuery` key that reads it.
- Custom hooks: a change to a hook's return value reaches every component that calls it.
- Routes and links: routes are strings. A renamed route breaks `<Link to>`, `navigate(...)`, bookmarks, emails and other apps that link to it.
- Events and messages: `window.addEventListener`, `postMessage`, a WebSocket or SignalR handler, and an event bus react to a change with no call site.
- Dynamic imports and `lazy`: a moved file changes a chunk. A search for the import path still finds it.
- Tests and mocks: a changed service or hook needs the `msw` handlers, `__mocks__` folders and test data to change as well.

## Data

- `localStorage`, `sessionStorage`, IndexedDB and cookies hold values from older builds. A renamed key, or a changed shape, meets the old stored value on the next visit. Look for a stored-version number or a migration.
- A persisted Redux or Zustand store has the same risk.
- Search the code for the storage key as a string, because the compiler does not check it.

## Configuration

- `VITE_*` and `REACT_APP_*` values are baked into the bundle at build time. A key added to one `.env*` file or one pipeline variable group and not the others breaks one environment only. Name the key, never the value.
- Values in `public/` files or a config fetched at run time change without a build.
- Feature flags and remote configuration, if the app has them.
- Build and hosting set-up: the bundler configuration, proxy settings for the API, the base path, and the server's rewrite rule for client-side routes.

## Libraries

- Pinned versions are in the lock file. Read the source of the library at that version. A major version of React, the router or the data library can change behaviour.
- Check peer dependencies and the Node version in `engines` before a raised or lowered version.
- A new library adds to the bundle size. A removed one can break an import elsewhere.

## Authorisation

- Role checks in the app only hide controls and routes. Find where the server enforces the rule, and whether the change moves it.
- Sign-in scopes, token lifetime and silent refresh: check that a changed scope or claim does not log out users.

## Run and count tests

- Read the test command from `package.json` `scripts` and the pipeline file, but do not run a script by name. A script such as `test` can start watch mode, run a `pretest` hook, run a build, or chain end-to-end tests. Read the script body, then run the runner directly with one file or one test. Copy the flags, the config file and the environment variables from the script body, for example `TZ` or `--config`. Use `vitest run <file> -t "<name>"` or `jest <file> -t "<name>"`. For Create React App, which hides its Jest configuration, use `CI=true react-scripts test <file>` instead. Use the runner from `node_modules/.bin` or the package manager's `exec`. Never use `npx` for a runner that is not installed: it downloads the latest version from the network.
- A filter that names no test can exit 0 and run zero tests, depending on the runner and its configuration. Check the total in the output and compare it with the count in the Commands heading of the contract. Jest prints the case total on its `Tests:` line. `jest --listTests` lists files only.
- Run only unit and component tests that need no network, account or configured service. Put the command on the run plan.
- `npm ci` writes `node_modules` and fetches packages over the network. If dependencies are missing, the proof stays `unknown:` and the engineer gets the command.
- Never run end-to-end tests (Playwright, Cypress) from this skill, even when the contract allows starting the app. They start a browser and may need a signed-in account or a network service.
