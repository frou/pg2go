[![PDD status](http://www.0pdd.com/svg?name=frou/pg2go)](http://www.0pdd.com/p?name=frou/pg2go)

[pg2go] is a [PostgreSQL] script that generates [Go] struct definitions for all
tables in a database.

It is designed to be run directly against a database using the official `psql` command, and the output of that redirected to a new `.go` source file.

Here is an example Unix shell session demonstrating this (it interacts with a hypothetical database called `blogdb`):

```shell
DB=blogdb
OUT_FILE="types_$DB.go"

echo "package main" >"$OUT_FILE"
psql --quiet --tuples-only --no-align --dbname "$DB" --file pg2go.sql >>"$OUT_FILE"

goimports -w "$OUT_FILE" || gofmt -w "$OUT_FILE"
```

Finally, we can peek at the contents of the generated `.go` file using the `head` command:

```shell
head -n 22 types_blogdb.go
```

```go
package main

import (
    "database/sql"
    "time"
)

type Author struct {
    ID         int       `db:"id" json:"id"`
    Created    time.Time `db:"created" json:"created"`
    Name       string    `db:"name" json:"name"`
    Admin      bool      `db:"admin" json:"admin"`
    LoginEmail string    `db:"login_email" json:"login_email"`
    LoginSalt  []byte    `db:"login_salt" json:"login_salt"`
    LoginKey   []byte    `db:"login_key" json:"login_key"`
}

type Comment struct {
    ID      int       `db:"id" json:"id"`
    Created time.Time `db:"created" json:"created"`
    Post    int       `db:"post" json:"post"`
    Author  int       `db:"author" json:"author"`
```

# Notes

Using the [goimports] command rather than the standard `gofmt` command to format the resultant file has the benefit of automatically adding import statements for packages if and only if they are used in what was generated (e.g. `"time"` for `time.Time` & `"database/sql"` for `sql.NullString`).

Struct fields are tagged `db:"..."` for [package sqlx][sqlx] to pick up on, should you wish to use it. Similarly, `json:"..."` for the standard library package `encoding/json`.

An [attempt](https://github.com/frou/pg2go/blob/master/pg2go.sql#L83) is made to singularize plural table names.

If `NEED_GO_TYPE_FOR_...` shows up in the resultant file then add a case for that type name to the `type_pg2go` function in `pg2go.sql`.

If the tables you're interested in aren't in the default `'public'` schema of your database, then search and replace that text in `pg2go.sql`.

## Support for Enums

When the database schema has something like:

```plpgsql
CREATE TYPE post_status AS ENUM ('draft', 'live', 'retracted');

CREATE TABLE post (
  -- ...
  status post_status NOT NULL
  -- ...
);
```

The resultant file will contain:

```go
type Post struct {
    // ...
    Status string `db:"status" json:"status"` // Postgres enum. Use with the PostStatus* constants.
    // ...
}

// ...

const (
    PostStatusDraft     = "draft"
    PostStatusLive      = "live"
    PostStatusRetracted = "retracted"
)
```

A value other than one of those constants will be rejected by Postgres when performing an `INSERT` or `UPDATE`.

# License

```text
The MIT License

Copyright (c) 2015 Duncan Holm

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

[pg2go]: https://github.com/frou/pg2go
[postgresql]: https://www.postgresql.org
[psql]: http://www.postgresql.org/docs/current/static/app-psql.html
[goimports]: https://godoc.org/golang.org/x/tools/cmd/goimports
[go]: https://www.golang.org
[sqlx]: https://github.com/jmoiron/sqlx
