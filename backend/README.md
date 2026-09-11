# Linos backend

Dart `shelf` proxy with SQLite caching and Ultimate Guitar scraping.

## Run

```sh
cd backend
dart pub get
dart run bin/server.dart
```

The server listens on `http://0.0.0.0:8080` by default. Override the port with the
`PORT` environment variable:

```sh
PORT=9000 dart run bin/server.dart
```

Android emulators reach it via `http://10.0.2.2:8080`.

## Verify

```sh
cd backend
dart analyze
dart test
```