# Certifications Tracker — SwiftUI (iOS 26, Liquid Glass)

Sign in with your Supabase account, keep a list of certifications and see how they group by tag and by provider.

Requires **Xcode 26** and the **iOS 26 simulator/SDK**.

## Quick start

```sh
cp swift/CertsConfig.example.plist swift/CertificationsTracker/Resources/CertsConfig.plist   # then fill in real values
open swift/CertificationsTracker.xcodeproj
```

The values are the same `SUPABASE_URL` and `SUPABASE_ANON_KEY` the other apps use. Without the file the app shows a "not configured" screen. The `cert_` migration (supabase repo) has to be applied to that project first.

## What it does

- **Certifications**: list with name and provider on the left and earn and expiration dates on the right. Sort by name, provider, earn date or expiration date (default: earn date, newest first), search, swipe to delete.
- **Add / edit**: name, provider, earn date, optional expiration date, verification link, tags and an optional PDF (up to 20 MB). Tags are multi-select; existing tags are suggested as you type and new ones can be created.
- **Detail**: dates, status (expired / expiring in 90 days), the verification link opens in an in-app browser, tags as chips, and the PDF opens in a viewer with share.
- **Courses**: their own tab, never mixed with certifications. Each course has a name, provider (where you took it: Udemy, LinkedIn Learning…), price, earn date, hours, tags and an attached file (PDF, JPEG or PNG).
- **Price**: certifications also have a price. It is 0 until you set it.
- **Search**: the search button next to the tab bar looks through certifications and courses.
- **Dashboard**: switch between Certifications (counts by tag and by provider) and Courses (hours and number of courses by category (tag) and by provider).
- **Settings**: change email and password, Face ID unlock, language, theme, About, Privacy and Terms.

## Behind a corporate network

If sign-in fails with `NSURLErrorDomain -1200` / `-9802`, trust the corporate root CA in the booted simulator (keep the certificate out of git, `*.pem` is ignored):

```sh
swift/scripts/trust_dev_proxy_cert.sh path/to/corporate_root_ca.pem
```

## Tests

```sh
cd swift/Packages/CertsCore && swift test
```

## Strings

Edit `scripts/strings.json`, then `python3 scripts/build_xcstrings.py`.

## Importing existing certificates and courses

`scripts/certifications.json` (53 certifications) and `scripts/courses.json` (347 courses) list name, provider, dates, hours, tags… matching the files in `curriculum/Certifications` and `curriculum/Courses`. After filling `CertsConfig.plist`:

```sh
export CERTS_EMAIL=you@example.com            # the account you sign in with
python3 scripts/upload_certifications.py --pdf-dir /path/to/Certifications --courses-dir /path/to/Courses --dry-run
python3 scripts/upload_certifications.py --pdf-dir /path/to/Certifications --courses-dir /path/to/Courses
```

It signs in as you (anon key + your password, so row level security applies), uploads each file to `cert-pdfs` and upserts the row. Pass only one of the folders to import just that part. Re-running updates the same rows. Prices are 0 in both files; hours are 0 for courses whose certificate prints no duration.
