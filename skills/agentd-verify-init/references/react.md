# React frontends

Load this file in Flow step 4, when a `package.json` in the repository, including one in a workspace folder, lists `react-dom` under `dependencies`. It shapes the text under "Driving it" in each feature file and the browser steps in the helpers. These notes come from general knowledge of the platform. They are not yet checked on a project. Treat each row as a place to look first, not a guarantee. Mark a recipe built only from these notes `inferred:`.

## Build and ports

| Fact | Where to look |
|---|---|
| Bundler | `vite`, `webpack`, `next` or `react-scripts` in `package.json`. A Vite project has `vite.config.*`. |
| Start command | The `scripts` block in `package.json` (`dev`, `start`). Read the command from there. |
| Port | `server.port` in `vite.config.*`, a `--port` flag in the script, or a `.env*` key. A fixed port means one UI at a time. |
| Ready | Poll the port until it answers an HTTP request, then load the page in the browser. A process that is listening has not finished building. |
| API address | A `.env*` key or a config module. Name the key, never the value. |

## Sign-in

- Find the library: MSAL (`@azure/msal-react`), an OIDC client, or Auth0. Look for `loginRedirect` or `loginPopup`.
- With MSAL, `loginRedirect` leaves the app for the identity provider and comes back with a token. The token is kept in `localStorage` or `sessionStorage`, which the browser profile may keep between runs.
- The agent opens the page and stops. The engineer signs in with their own account. The agent never types credentials.
- After sign-in, check the page shows the signed-in user before driving anything.
- The proof run checks that the browser profile keeps the sign-in between runs. If it does not, say so in the Gotchas.

## Selectors

- Look for `data-testid` and `aria-label` in the source. Many projects have none.
- With no test ids, drive by visible text and role: the label of a button, a heading, a table column title.
- MUI components (`@mui/material`) render generic class names that change between builds. Do not select by those class names. Select a field by its label, and open a select or autocomplete by clicking it, then choose the option by its text.
- Take a fresh page snapshot after each action. Element references from an earlier snapshot go stale.

## Grids

- A virtualised grid (MUI X DataGrid, AG Grid, `react-window`) renders only the rows on screen. A row below the fold is not in the page.
- Scroll the grid, or filter or sort it, until the row is on screen. Then read it.
- Read a cell's displayed text, then the API response for the same value. Do not count rows in the page and call that the total.
- A grid drop-down cell commits only when the option is clicked, not with Enter.
- Pinned columns and column groups can repeat a cell in two places. Check which one a step means.

## Downloads

- A download is evidence. Save the file in the evidence folder, with the step number in its name.
- A browser may block a second download or ask where to save it. Set the download folder to the evidence folder for the run.
- Read the file after the download. For a spreadsheet, compare a few cells with the screen and the API.
- Report the file name and the cells checked. Never paste customer values into a feature file.

## ui-start.ps1

Parameters: ticket. Starts the UI dev server and waits until the port answers an HTTP request. Prints the URL and the
process ID, and saves the process ID in `state.json`. Refuse when a process this run did not start holds the port.

- When a dependency is missing, it stops with `blocked: <reason>` and prints the fix command. It never runs the command
  itself. The fix command must not change tracked files (for npm, `npm ci`, never `npm install`).
