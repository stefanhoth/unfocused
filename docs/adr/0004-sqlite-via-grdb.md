# SQLite via GRDB as the local database

All data lives in one local SQLite file, accessed through GRDB with explicit, versioned migrations. Activity produces a constant stream of small timestamped records that have to be queried by time range and grouped by Loop, and Loop titles need full-text search. SwiftData is pleasant for simple object graphs but weak at time-series queries, migrations and testing outside an app, and it hides the storage format. GRDB keeps the database a plain file that tests, a future CLI and the user can open directly.
