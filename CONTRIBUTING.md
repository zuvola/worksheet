# Contributing

Thanks for your interest in contributing to Worksheet. This guide explains how to set up the repo, make changes, and submit a pull request.

## Quick Start

1. Clone the repo
   ```bash
   git clone https://github.com/sjhorn/worksheet.git
   cd worksheet
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Run the demo
   ```bash
   flutter run -t example/main.dart
   ```

## Development Workflow

1. Write a test first for new behavior.
2. Implement the minimal change to pass the test.
3. Refactor while keeping tests green.

Keep tests in sync with source layout. Example: `lib/src/core/geometry/span_list.dart` maps to `test/core/geometry/span_list_test.dart`.

## Tests

Run all tests:
```bash
flutter test
```

Run a specific test:
```bash
flutter test test/core/models/cell_coordinate_test.dart
```

Run benchmarks:
```bash
flutter test test/benchmarks/
```

## Code Style

- Follow the Dart style guide.
- Run formatting before PRs:
  ```bash
  dart format lib/ test/
  ```
- Run analysis:
  ```bash
  dart analyze lib/
  ```

## Documentation

Update or add docs under `doc/` when you change public behavior or APIs.

## Commit Messages

We follow Conventional Commits:
- `feat:` new feature
- `fix:` bug fix
- `docs:` docs only
- `test:` tests only
- `refactor:` refactor
- `chore:` maintenance

## Pull Request Checklist

- Tests added or updated
- `flutter test` passes
- `dart analyze` passes
- Docs updated if behavior or API changed
- Benchmarks updated if you touched O(N) or rendering code
