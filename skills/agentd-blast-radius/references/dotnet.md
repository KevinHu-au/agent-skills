# .NET projects

Where to look in a .NET project. These notes come from general knowledge of the platform. They are not yet checked on a customer project.

## Wire shapes

- JSON names come from the serialiser settings and from attributes. Check the naming policy of `System.Text.Json`, `[JsonPropertyName]`, and `[JsonProperty]` for Newtonsoft. A property rename changes the wire name unless an attribute pins it.
- SOAP and XML: `[DataContract]` and `[DataMember]` names, `XmlSerializer` attributes, WCF service contracts and WSDL files. A schema or map in an integration platform such as BizTalk reads these names. That map is not in this repository: `unknown: ask <owner>`.
- Swagger or OpenAPI documents and generated clients (NSwag and similar) may need a regenerate. Find the command in the contract.

## Data

- Entity Framework: the migration and the model snapshot (`*ModelSnapshot.cs`). A property rename can be generated as a drop and an add, which loses data. Read the generated migration before you trust it.
- DbUp or plain SQL scripts: an applied script is not edited. Look for the next script. Stored procedures that the project re-runs on each deploy are edited in place.
- Find the readers of a column: search the code for the name, then on SQL Server search `sys.sql_modules` where `definition` contains the name, and read `sys.sql_expression_dependencies`. Dynamic SQL built from strings is in neither: search for the name as a string.
- Raw SQL in `FromSqlRaw`, Dapper queries and `.sql` files are strings. A compiler does not see them.

## Indirection

- Dependency injection: find the registration in `Program.cs` or `Startup.cs`. Look for assembly scanning, decorators and open generics.
- MediatR and similar: handlers are found by type. A new or removed handler changes behaviour without a call site.
- Background services, hosted services and scheduled jobs call code at times that a request trace does not show.

## Configuration

- `appsettings.json` and `appsettings.<Environment>.json`, user secrets, environment variables and a key vault. A binding by section name breaks silently when the key is renamed. Name the key, never the value.
- `web.config` transforms on older projects.

## Libraries

- Pinned versions are in the `.csproj`, `Directory.Packages.props` or `packages.lock.json`. Read the source of the library at that version. A behaviour can change between a major version and the next.
- Regular expressions: `RegexOptions.IgnoreCase` and `RegexOptions.CultureInvariant` change what a pattern matches. Culture changes string comparison and number formats.

## Authorisation

- `[Authorize]` attributes, policies and handlers. Check where the rule is enforced, and whether the change moves it.

## Run and count tests

- A test filter that matches zero tests can still exit 0, with only a warning. Check the total in the output, or list the tests with the same filter. Compare with the count in the Commands heading of the contract.
