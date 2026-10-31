# React frontends

Where to look in a React web app. The stack signals in `SKILL.md` say what counts as one. A React Native app does not use `react-dom`. These notes come from general knowledge of the platform. They are not yet checked on a customer project. The test flags below were not run.

## Run and count tests

- Read the test command from `package.json` `scripts` and the pipeline file, but do not run a script by name. A script such as `test` can start watch mode, run a `pretest` hook, run a build, or chain end-to-end tests. Read the script body, then run the runner directly with one file or one test. Copy the flags, the config file and the environment variables from the script body, for example `TZ` or `--config`. Use `vitest run <file> -t "<name>"` or `jest <file> -t "<name>"`. For Create React App, which hides its Jest configuration, use `CI=true react-scripts test <file>` instead. Use the runner from `node_modules/.bin` or the package manager's `exec`. Never use `npx` for a runner that is not installed: it downloads the latest version from the network.
- Run only unit and component tests (React Testing Library) that need no network, account or configured service. Put the command on the run plan.
- Never run end-to-end tests (Playwright, Cypress) from this skill, even when the contract allows starting the app. They start a browser and may need a signed-in account or a network service.
- A filter that names no test can exit 0 and run zero tests, depending on the runner and its configuration. Check the total in the output and compare it with the count in the Commands heading of the contract. `jest --listTests` lists test files, not test cases, so it cannot confirm a case count. Read the `Tests:` line of the Jest output instead. `vitest list` lists cases on a Vitest version that has it (check `vitest --help`). If the count cannot be read, it stays `unknown:`.
- `npm ci` writes `node_modules` and fetches packages over the network. If dependencies are missing, say so and give the engineer the command. Do not install them.
- Output that depends on the clock, the time zone or the locale (`Date`, `Intl`) can pass on one machine and fail on another. Such a difference is not evidence.

## Bug candidates

- Effects: a missing or wrong dependency array in `useEffect`, `useMemo` or `useCallback`; an effect that runs twice in development Strict Mode; a missing cleanup for a timer, listener or subscription.
- Stale state: a closure that reads an old value, a state update that reads the previous value without the function form, state copied from props and never updated.
- Race conditions: a request that returns after a newer one or after the screen has gone, with no abort or ignore flag; a double submit.
- Rendering: a list `key` made from the array index or a new random value, an object or function created on each render that is passed to a memoised child, state mutated in place.
- Data and decoding: a response field that is missing, null or renamed, which the code reads without a check. TypeScript types are not checked at run time. A generated client can be out of date against the API.
- Time and locale: `new Date()` against a fixed time zone, `toLocaleString` and `Intl` with the browser locale, date strings parsed without a time zone, number and currency formats.
- Sign-in: token expiry and silent refresh, a token cached across accounts, a redirect loop after sign-in.
- Cache: a React Query or store entry that is not invalidated after a write, a browser or CDN cache that serves an old bundle.
- Environment: `VITE_*` or `REACT_APP_*` values are set at build time, so a build for one environment shows another environment's value. Name the key, never the value.
- Browser: a feature missing in an older browser, mobile layouts, and a browser extension that changes the page.

## Data candidates

- The data lives in the browser or on a server. Find which: the browser store, the code that writes it, and the API it calls.
- Find the writers of a stored value: the form handlers, the store actions, the import code. Find the readers too. A `localStorage` key is a string that other code reads, so search for the key as a string.
- Rows the app writes on the server: find the request that writes them, then the server's handler. The server code is often in another repository: `unknown: ask the <system> owner`, or ask the engineer for its path and read it as SKILL.md, Rules, says.
- Do not read a customer's browser storage or a production database. Reproduce with synthetic data in a local build only if the contract's Commands or Verify heading allows starting the app. Otherwise mark the fact `unknown:` and give the engineer the steps.
- Logs, network traces and error-tracking events can hold personal data. Read only what the ticket needs, and quote none of it.

## Performance candidates

- Measure with the browser performance panel on a production build. A development build runs extra checks and is slower. The React Profiler records commits only in a development build or a profiling build (`react-dom/profiling`). A standard production build gives an empty profile, which is not evidence that re-renders are fine. A profile needs the app running. Start one only if the contract allows starting the app. Otherwise give the engineer the steps.
- Re-renders: a context value that changes on each render, state held too high in the tree, a missing `memo`, `useMemo` or `useCallback` where a child is costly, an inline object passed as a prop.
- Long lists: no virtualisation, an unstable `key`, heavy work in the render body, images at full size.
- N+1: a request per row, or per component that mounts. The cost is the request count. Count the requests in the browser Network panel or in the project's own request logging.
- Waterfalls: a request that waits for another that it does not depend on, and a refetch on each focus or mount.
- Bundle size: a large library imported for one function, no route-level `lazy` loading, or duplicate packages in the bundle. The bundler's analyser (`rollup-plugin-visualizer`, `webpack-bundle-analyzer`) shows this.
- Load time: work done before the first screen, such as sign-in, configuration fetches and SDK start-up.
