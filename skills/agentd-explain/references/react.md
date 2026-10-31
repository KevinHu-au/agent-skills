# React frontends

Load this file for a React web project (the stack signals in `SKILL.md`; a React Native app does not
count). Treat each row as a place to look first, not a guarantee. The
trail leaves this file at the API call; the backend layers come from the backend's reference, or from the generic
order in `SKILL.md`.

## Detect

The stack signals in `SKILL.md` decide when to load this file. These lines say what to look for once it is loaded.

- `package.json` with `react` and `react-dom`; a bundler such as Vite (`vite.config.*`) or webpack.
- `*.tsx` or `*.jsx` files under `src/`.

## Layers

1. Page: the route's top component, where the figure or status is shown.
2. Context or store: a React context provider, or a store (Redux, Zustand, React Query cache) that holds the data.
3. Hook: a custom hook (`use*`) that loads the data for the page.
4. Service: the module that makes the HTTP call.
5. Generated client: an API client and model types generated from the backend's OpenAPI document. It names the
   endpoint the call reaches.

A layer the frontend does not use is `none`, for example no context when the page calls its hook directly.

## Where to look

| Layer | Where to look |
|---|---|
| Page | The router (`react-router` `<Route>` or `createBrowserRouter`, or a `routes` folder); `pages/` folders; the component that renders the label the engineer named |
| Context or store | `createContext` and its provider; `useContext`; Redux slices; React Query `useQuery` keys |
| Hook | `use*` functions in `hooks/` folders that call a service |
| Service | `services/` or `api/` folders; `fetch`, `axios` or the generated client's methods |
| Generated client | NSwag output (`nswag.json`, a large `*-models.ts` or `api-client.ts`), OpenAPI generator output; the command that regenerates it |
| Calculation in the frontend | Functions that compute a figure from several fields before it is shown: `utils/`, selectors, `useMemo` blocks. Then trace each input to its source. |
| Configuration | `.env*` files, a `config` module. Name keys only. |
