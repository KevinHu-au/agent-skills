# React frontends

Load this file for a React web project (the stack signals in `SKILL.md`; a library does not count). The root `package.json` of a monorepo may list only workspaces. A React Native app does not use `react-dom`. This file says where a React app keeps the things the explorers look for. Treat each row as a place to look first, not a guarantee. These notes come from general knowledge of the platform. They are not yet checked on a customer project.

## Runtime and layout

| Fact | Where to look |
|---|---|
| Framework and build tool | `react`, `react-dom` and the bundler in `package.json` (`vite`, `webpack`, `next`, `react-scripts`); `vite.config.*`, `webpack.config.*`, `next.config.*`. A README often disagrees. The lock file and `package.json` win. |
| Language | `tsconfig.json` and `*.tsx` against `*.jsx` files |
| Package manager and versions | `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`; `engines` and `.nvmrc` for the Node version |
| App entry | `src/main.tsx` or `src/index.tsx` (`createRoot(...).render`); the root `App` component and its providers |
| Configuration | `.env*` files (`VITE_*` or `REACT_APP_*` keys are readable in the browser), a `config` module, `public/` files loaded at run time. Name keys only. |

## Behaviour

| Fact | Where to look |
|---|---|
| Screens and routes | `react-router` (`<Route>`, `createBrowserRouter`), a `routes` folder, `pages/` or `app/` folders (Next.js) |
| Navigation guards | A protected-route component or a route loader that redirects when no user is signed in |
| State | `useState` and `useReducer` in the page; `createContext` and its provider; Redux slices, Zustand stores, React Query `useQuery` keys. Note which style each screen uses. |
| Forms | `react-hook-form`, Formik, or controlled inputs; the validation schema (`zod`, `yup`) and the submit handler |
| Data loading | Hooks that fetch (`useQuery`, `useEffect`), services or API clients, and route loaders |
| Calculations | Selectors or helpers that compute grid or total values, and `useMemo` blocks |
| Business rules | Hooks (`use*`), `utils/` and selector functions that compute a value before it is shown. The server is the real gate for rules. |
| Permissions and roles | Claims in the sign-in token; code that hides or disables a control by role. The server is the real gate: `unknown: ask the API owner`. |
| Background work | Polling with `setInterval` or a React Query `refetchInterval`; WebSocket or SignalR connections; service workers |

## Data

| Fact | Where to look |
|---|---|
| Local store | `localStorage`, `sessionStorage`, IndexedDB, cookies, a persisted Redux or Zustand store |
| Wire shapes | TypeScript interfaces and `zod` schemas for the API response; the mapping from the response to the view model |
| Generated files | NSwag output (`nswag.json`, `*-models.ts`, `api-client.ts`), OpenAPI generator output, GraphQL codegen. Find the command that regenerates each. |

## External systems

| Fact | Where to look |
|---|---|
| HTTP | `fetch`, `axios` instances, the generated client; the base address in the `.env*` files or a config module (name the key, never the value) |
| Sign-in | MSAL (`@azure/msal-react`), Auth0 or OIDC client libraries, token storage and refresh code |
| SDKs | Analytics, error tracking (Sentry, Application Insights), map and payment SDKs, feature flag clients |
| Build and release | `azure-pipelines.yml`, `ci.yml`, `Dockerfile`, a static hosting or web server config. Name the files, never the secrets. |
| Inbound | `postMessage` listeners, deep links to routes, embedded iframes |

## Tests

| Fact | Where to look |
|---|---|
| Test files | `*.test.tsx`, `*.spec.tsx`, `__tests__/` folders; Vitest or Jest (`vitest.config.*`, `jest.config.*`); React Testing Library |
| Run | The `scripts` block in `package.json` and the pipeline file show the exact command. Read the command from them. Do not run it here: `safe-checks.md` lists what may run. |
| End-to-end tests | Playwright or Cypress under `e2e/` or `cypress/`. They start a browser and may need a signed-in account or a network service. Never run them from this skill. |
| Mocks | `msw` handlers, `__mocks__/` folders, mocked service modules. They show which calls the tests expect. |
