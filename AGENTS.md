# Agent instructions

Instructions for AI and human collaborators using tools such as **Cursor** and **Claude** in this repository.

## Project structure

The repo holds the native SwiftUI app in `swift/` (iOS 26, Liquid Glass). It follows the layout and conventions of the sibling **Gym-Tracker**, **Wallet** and **MMA-ScoreCard** Swift apps.

```
swift/
  Packages/CertsCore/
    Sources/CertsCore/   # Certification and Course entities, sorting, tag helpers, dashboard stats, date coding. No I/O.
    Sources/CertsData/   # CertsRepository (Supabase tables + file bucket), OfflineCache, CertsConfig
    Tests/               # Swift Testing suites
  CertificationsTracker/
    App/                 # app entry, RootView (auth + biometric lock), AppModel, Preferences, L10n, tab shell
    Features/            # Auth, Certifications and Courses (list, detail, editor), tag picker, file viewer, in-app browser, Search, Dashboard (certifications / courses), Settings
    Components/          # date formatting, tag chips, flow layout
    Resources/           # assets, Localizable.xcstrings (English and Spanish), CertsConfig.plist (git-ignored)
  scripts/               # build_xcstrings.py + strings.json, trust_dev_proxy_cert.sh
```

- **Supabase holds auth, data and PDFs.** The tables are `cert_certifications` and `cert_courses`; the bucket is `cert-pdfs` (private, one folder per user: `<userId>/<certificationId>.pdf` and `<userId>/courses/<courseId>.<pdf|jpg|png>`). They live in the sibling `supabase` repo (`supabase/migrations/*_cert_certifications.sql`, docs in `docs/cert/schema.md`). Never add migrations here; change the schema there.
- Courses never appear in the certifications list; their tags are the dashboard "categories". Tags are a `text[]` column, normalized to lower case (`TagTools.normalize`). There is no tag table: suggestions and the per-tag counts are computed from the loaded certifications.
- Reads fall back to an on-device JSON cache (`OfflineCache`) when offline; writes need a connection. Sign-out clears the cache.
- Strings: edit `swift/scripts/strings.json` (English and Spanish), then run `python3 swift/scripts/build_xcstrings.py` to regenerate `Localizable.xcstrings`.
- The project uses a synchronized folder, so new files under `swift/CertificationsTracker/` are picked up by Xcode automatically.
- Before finishing a change: `cd swift/Packages/CertsCore && swift test`, and build the app (`xcodebuild -project swift/CertificationsTracker.xcodeproj -scheme CertificationsTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`).

## Git commits and branches: explicit user approval is required

**Never commit changes to git unless the user explicitly asks you to.** Make all code changes, then wait for the user to request a commit before running any `git commit` command. Proposing a commit message is fine; running the commit is not.

**Never create a git branch unless the user explicitly asks you to.** Do not run `git branch` or `git checkout -b` (or equivalent) on your own, even to prepare for a commit or Merge Request.

## Pull Requests: use the project template

When creating a GitHub Pull Request, always fill in the description using [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md). GitHub loads that file automatically. Replace each `<!-- … -->` comment with concrete content based on the actual changes. Do not leave placeholder comments in the final description.

## Commits: Conventional Commits (required)

Every commit message **must** follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

### Format

```
<type>[optional scope]: <short description>

[optional body]

[optional footer(s)]
```

- **Description:** imperative mood, lowercase start (a trailing period is not required, but stay consistent).
- **Maximum header length:** keep the first line at ≤ **72** characters when possible.

### Allowed types (common)

Use one of: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

- **`feat`:** new user-facing behavior or capability.
- **`fix`:** a bug fix.
- **`docs`:** documentation only.
- **`chore`:** maintenance that is not a user-facing feature or fix (dependencies, configuration, tooling).
- **`ci`:** CI/CD pipeline or automation only.

### Scope (optional)

A noun in parentheses after the type, e.g. `fix(postgres): handle null connection string`.

### Breaking changes

Either of:

- add **`!`** after the type/scope: `feat(api)!: remove legacy endpoint`, or
- add a footer: `BREAKING CHANGE: <what changed and what to do>`.

### Examples (valid)

- `feat(examples): add from-code compose sample`
- `fix(ci): use non-tls dind for self-hosted runners`
- `docs: clarify WAL-G vs backup-push in readme`
- `chore: bump gitlab-ci docker image tags`

### Examples (invalid — do not use)

- `Update dockerfile` (missing type)
- `Fixed bug` (not conventional)
- `WIP` / `misc changes`

When proposing or creating commits, **always** use this format. If there are multiple unrelated changes, **split them into several commits** instead of one vague message.
