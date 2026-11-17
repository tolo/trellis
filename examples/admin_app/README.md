# Contacts admin example

A Shelf app that renders and updates a contacts directory using Trellis UI fragments and HTMX.

```sh
dart pub get
dart run bin/server.dart
```

Open [http://127.0.0.1:8080/](http://127.0.0.1:8080/). Set `PORT` to listen on a different port. The directory starts with 23 in-memory contacts each time the server starts.

Search, filter by status, sort by a column and open a row's Actions menu to edit or delete a contact. The New contact dialog uses the same form as Edit. Select a company from the suggestions and switch to Summary to see counts by status. Changes update both tabs and announce a toast.

The app serves pinned HTMX and embedded Trellis UI assets from its own origin under the strict CSP preset. The app stylesheet handles layout and page typography. Append a shadcn `:root` and `.dark` theme block there to change the suite's tokens. The `.dark` rules apply when the page has that class.

To deploy an AOT build, copy `bin/server`, `templates/` and `static/` into the same directory tree on the target machine.

```sh
dart compile exe bin/server.dart -o bin/server
./bin/server
```

`dart test` checks the HTTP contracts, Chrome journeys, CSS and template footprint, and the binary after deployment to a temporary directory.
