# SplitWise — Setup Guide

## Prerequisites

| Tool | Minimum version | Install |
|------|----------------|---------|
| Flutter SDK | 3.22 | https://docs.flutter.dev/get-started/install |
| Dart SDK | 3.3 | (bundled with Flutter) |
| Xcode | 15+ | Mac App Store |
| Supabase CLI | 1.176+ | `brew install supabase/tap/supabase` |

---

## 1. Create a Supabase Project

1. Go to https://supabase.com and create an account if you haven't already.
2. Click **New project**, fill in name / password / region, click **Create new project**.
3. Wait ~60 seconds for provisioning.
4. In the sidebar go to **Project Settings → API**.
5. Copy:
   - **Project URL** — looks like `https://xxxxxxxxxxxxxxxx.supabase.co`
   - **anon / public key** — the long JWT string

---

## 2. Plug In Your Credentials

Open `lib/core/constants.dart` and replace the two placeholders:

```dart
static const String supabaseUrl     = 'https://YOUR_PROJECT_ID.supabase.co';
static const String supabaseAnonKey = 'YOUR_ANON_KEY';
```

---

## 3. Run the Database Migration

### Option A — Supabase Dashboard (easiest)
1. In your project, go to **SQL Editor**.
2. Click **New query**.
3. Paste the full contents of `supabase/migrations/001_initial_schema.sql`.
4. Click **Run**.

### Option B — Supabase CLI
```bash
# From the project root (splitwise_app/)
supabase link --project-ref YOUR_PROJECT_ID
supabase db push
```

---

## 4. Create the Receipt Storage Bucket

In the Supabase dashboard:
1. Go to **Storage → Buckets**.
2. Click **New bucket**.
3. Name it `receipts`, leave **Public bucket** unchecked (private).
4. Click **Create bucket**.
5. Go to **Storage → Policies** and create these two policies on the `receipts` bucket:

```sql
-- Allow authenticated users to upload receipts
create policy "authenticated_upload"
  on storage.objects for insert
  with check (
    bucket_id = 'receipts'
    and auth.role() = 'authenticated'
  );

-- Allow authenticated users to read receipts
create policy "authenticated_read"
  on storage.objects for select
  using (
    bucket_id = 'receipts'
    and auth.role() = 'authenticated'
  );
```

---

## 5. Configure Email Auth (optional but recommended)

In Supabase dashboard → **Authentication → Providers → Email**:
- Disable **Confirm email** during development if you want instant login after sign-up.
- Re-enable it before shipping to production.

---

## 6. Install Flutter Dependencies

```bash
cd splitwise_app
flutter pub get
```

---

## 7. Run the iOS Simulator

```bash
# List available simulators
open -a Simulator

# Run the app
flutter run -d "iPhone 15 Pro"
```

For physical device, make sure your Apple developer account is configured in Xcode.

---

## 8. Features Walkthrough

### Auth
- Launch the app → you'll be taken to the login screen.
- Tap **Sign up** to create an account.
- A profile row is automatically created in `profiles` via a database trigger.

### Groups
- After login you land on **My Groups**.
- Tap **New Group**, choose an emoji, enter a name.
- From the group detail screen tap the **Invite** button to add members by email (they must have a SplitWise account).

### Adding Expenses (Manual)
- Inside a group tap **Add Expense** (FAB).
- Fill in description, amount, currency.
- Select who paid and who splits.
- Choose split type: Equal / By item / Custom.
- Tap **Save Expense**.

### OCR Receipt Scanning
- On the Add Expense screen tap the **scanner icon** (top-right).
- The camera opens — take a photo of the receipt.
- ML Kit processes the image on-device (no internet needed).
- You land on the **Review Receipt** screen showing detected items.
- Check/uncheck items; optionally assign each item to specific members.
- Tap **Use These Items** — the form is pre-filled with total and items.

### Voice Entry
- On the Add Expense screen tap the **microphone icon** (top-right).
- Speak a sentence like:
  - *"Thirty euros for pizza"*
  - *"I paid 45.50 for groceries"*
  - *"John paid one hundred euros for the hotel, split with Anna and me"*
- Tap the mic again to stop.
- The form fields are auto-populated with the extracted data.

### Balances
- From a group's detail screen tap the **wallet icon** (top-right).
- The balances screen shows each member's net position (green = owed money, red = owes money).
- The **Suggested Payments** section shows the minimum set of transfers to settle all debts.

---

## Project Structure

```
splitwise_app/
├── supabase/migrations/001_initial_schema.sql   ← Database schema + RLS
├── lib/
│   ├── main.dart                               ← App entry point
│   ├── app.dart                                ← GoRouter + MaterialApp
│   ├── core/
│   │   ├── constants.dart                      ← ⚠️ Put your credentials here
│   │   ├── theme.dart
│   │   └── utils/
│   │       ├── currency_utils.dart
│   │       └── debt_simplifier.dart
│   ├── features/
│   │   ├── auth/                               ← Login, Register, AuthProvider
│   │   ├── groups/                             ← Groups list, create, detail
│   │   ├── expenses/                           ← Add, list, detail expenses
│   │   ├── ocr/                                ← ML Kit scanner + parser + review
│   │   ├── voice/                              ← speech_to_text + NLP parser
│   │   └── balances/                           ← Net balances + debt simplifier
│   └── shared/
│       ├── widgets/                            ← LoadingOverlay, UserAvatar, AmountInput
│       └── repositories/                       ← Supabase CRUD wrappers
├── pubspec.yaml
└── ios/Runner/Info.plist                       ← Camera + microphone permissions
```

---

## Common Issues

| Symptom | Fix |
|---------|-----|
| `401 Unauthorized` from Supabase | Wrong anon key in `constants.dart` |
| RLS error on insert | Make sure you're logged in; check that the trigger created a `profiles` row |
| Camera/mic permission denied on iOS | Delete app, re-run; accept permissions on first launch |
| "Speech recognition not available" | Run on a physical device or a simulator with iOS 17+ |
| OCR returns empty text | Use good lighting; ensure the receipt image is sharp |
| `build_runner` errors | Run `flutter pub run build_runner build --delete-conflicting-outputs` |

---

## Next Steps

- **Push notifications**: Notify group members when a new expense is added (Supabase Realtime + APNs).
- **Currency conversion**: Integrate Open Exchange Rates API for multi-currency groups.
- **Settlement confirmation**: Let users mark settlements as confirmed in the database.
- **Export**: Generate a PDF summary of group expenses.
- **Android support**: The codebase is cross-platform; only minor tweaks needed (permissions manifest).
