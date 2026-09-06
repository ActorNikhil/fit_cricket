# App Store Listing — Fit Cricket

Copy-paste ready text for App Store Connect. Character counts are noted against
Apple's limits so nothing gets truncated. Placeholders in [brackets] need your
input before submitting.

---

## App Name (limit 30)
`FitCricket`
_(10 chars)_

## Subtitle (limit 30)
`Score matches, burn calories`
_(28 chars)_

Alternates:
- `Live scoring & fitness tracker` (30)
- `Cricket scorer for your team` (28)

---

## Promotional Text (limit 170 — editable anytime without review)
`Score every match ball-by-ball, follow your team's games live, and see the calories you burn batting, bowling and fielding. Your cricket, synced across all your devices.`
_(168 chars)_

---

## Keywords (limit 100, comma-separated, NO spaces after commas)
`cricket,scorer,scoreboard,score,match,live,team,batting,bowling,calories,fitness,stats,tracker,gully`
_(99 chars)_

Notes:
- Don't repeat words already in the app name/subtitle (Apple indexes those
  separately), so "cricket" is borderline — keep it, it's your core term.
- No plurals if the singular is present; Apple matches both.

---

## Description (limit 4000)

```
Fit Cricket is the easy way to score your cricket matches and track how much you move while you play.

Whether it's a weekend gully game, a club fixture, or a tournament, set up your teams, score ball-by-ball, and get a full scorecard the moment the match ends — no paper, no spreadsheets.

SCORE EVERY BALL
• Fast, tap-friendly scoring for runs, wickets, wides, no-balls and byes
• Live batting and bowling figures, run rate and target chase
• Automatic result, ties, and Man of the Match
• Complete scorecard with batting, bowling and fall of wickets

FOLLOW MATCHES LIVE
• See games you're part of update in real time, even when a teammate is scoring
• "Matches of your interest" keeps every game you played in one place
• Open any match for the full live scoreboard

BURN, TRACKED
• See the calories you burn from batting, bowling and fielding
• Today's breakdown plus a rolling history of your activity
• A fun way to turn game day into fitness

BUILT FOR YOUR TEAM
• Save teams and player rosters and reuse them each match
• Your profile, teams, matches and stats sync across your devices
• Works fully offline — score anywhere, sync when you're back online

Create a free account, set up your first team, and start scoring in minutes.

Calorie figures are estimates based on your in-game activity and are intended for fun and general motivation, not medical or fitness measurement.
```
_(~1,300 chars — well under the 4,000 limit; trim or expand freely.)_

---

## What's New (version 1.0)
`First release of Fit Cricket! Score matches ball-by-ball, follow your team's games live, and track the calories you burn on the pitch.`

---

## Other App Store Connect fields
- **Support URL** (required): [your support page or a simple contact page]
- **Marketing URL** (optional): [your website, if any]
- **Privacy Policy URL** (required): [hosted URL of PRIVACY_POLICY.md]
- **Primary Category:** Sports
- **Secondary Category (optional):** Health & Fitness
- **Age Rating:** likely 4+ (no objectionable content). Complete the
  questionnaire honestly; user-generated player names could nudge this — if you
  add any social/free-text sharing later, revisit.
- **Copyright:** `© 2026 [DEVELOPER/COMPANY NAME]`

## Review notes (App Review Information → Notes)
Suggested text for the reviewer, since the app needs an account:
```
This app requires a free account to sync cricket data across devices.
Demo account:
  Email: [demo email]
  Password: [demo password]
The account already has sample teams and matches so all features (scoring,
live matches, calories, profile) can be exercised immediately.
```
Create that demo account in your production Supabase before submitting — App
Review will reject a login-gated app if they can't get in.
