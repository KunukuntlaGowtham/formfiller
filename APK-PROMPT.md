# Prompt — build an Android APK for SEVAK REGISTRY

Paste everything below the line into whichever tool is building the APK
(Claude Code, Cursor, an Android dev, Android Studio + an assistant).
Change the two values marked ⚠ first.

---

Build me a signed Android APK that wraps an existing web app. I am not
rewriting the app — it is one self-contained `index.html` already deployed
and working. The APK is a native shell around it.

## The app

- **Name:** SEVAK REGISTRY
- **Live URL:** `https://kunukuntlagowtham.github.io/formfiller/`  ⚠ confirm this is my Pages URL
- **Package id:** `com.sevak.registry`  ⚠ change if you prefer
- **Backend:** Supabase at `https://qzzcpuvcrhbasnnsfvgt.supabase.co`
  (PostgREST + Supabase Auth, called over HTTPS with `fetch`)
- Single HTML file, no build step, vanilla JS. Tabs: RECORDS, REGISTER,
  FAST ENTRY, TEAMS, STAFF, MONTH, TTD BOOKINGS, CONTROL, CHECKER.

## Load the live URL, do not bundle the HTML

I redeploy this app several times a week through GitHub Pages. Point the
WebView at the live URL so every deploy reaches the phone with no rebuild.
Do **not** copy `index.html` into `assets/` — I do not want to ship a new
APK for every change.

Show a branded splash/loading screen while the first load happens, and a
clear "no internet — retry" screen (with a Retry button) if the load
fails. The app is useless offline; say so plainly instead of showing a
blank white WebView or a Chrome error page.

## Use Capacitor

Use Capacitor (not Cordova, not a bare WebView Activity) with
`server.url` set to the live URL and `server.androidScheme: 'https'`.
Minimum SDK 24, target the current stable SDK.

## The five things that break in a WebView — handle each

These are not hypothetical; the app does all of them.

1. **File downloads.** The contacts export builds a vCard/CSV as a Blob
   and triggers `<a download>`. In a WebView this silently does nothing.
   Intercept it — `setDownloadListener` plus a `blob:`/`data:` handler, or
   the Capacitor Filesystem plugin — write the file to the Downloads
   folder, then offer a share sheet. The whole point is importing the
   result into Google Contacts, so the file must be reachable by other
   apps.

2. **Photo capture and file picking.** Registration uses
   `<input type="file" accept="image/*">` for pilgrim photos and documents,
   stored as base64. Wire `onShowFileChooser` so both "Camera" and "Files"
   work. Request CAMERA and the media/storage permissions at runtime, with
   a rationale dialog, and handle a permanent denial gracefully.

3. **localStorage must persist.** Sign-in sessions, the selected team, the
   control-room room name and panel settings all live in localStorage and
   must survive force-close and reboot. Enable DOM storage and make sure
   nothing clears the WebView data on exit.

4. **Hardware back button.** Back should navigate the WebView back if it
   can, otherwise ask "Exit SEVAK REGISTRY?" before closing. It must never
   drop out of the app mid-form.

5. **Staying awake.** The CONTROL tab polls Supabase every 4 seconds and
   the TTD scripts fire bookings at an exact time. Add a user-toggleable
   "keep awake" option that holds a wake lock while that tab is open, and
   prompt once to exempt the app from battery optimisation. Do not hold a
   wake lock permanently by default.

## Also do

- Portrait and landscape both, and handle rotation without reloading the
  WebView (`configChanges`).
- App icon and splash from a single source image I will supply; generate
  every density. Use a simple lightning-bolt-on-purple mark as a
  placeholder until I do.
- `usesCleartextTraffic="false"` — everything is HTTPS.
- Keep the WebView's own zoom off but respect the system font scale.
- No analytics, no crash reporting, no third-party SDKs. This app holds
  personal details of real people; nothing leaves the device except calls
  to Supabase.

## Deliver

1. The full project source, buildable with `./gradlew assembleRelease`.
2. A **release-signed APK** I can sideload. Generate a keystore, and give
   me the keystore file plus its passwords and alias in a separate note —
   do not commit them, and do not put them in the repo or the README.
3. A short README: how to rebuild, how to change the URL, and how to bump
   the version.

## How I will check it

- Install, open, sign in with my Supabase email/password → records load.
- Kill the app, reopen → still signed in.
- Register a pilgrim, take a photo with the camera → photo saves.
- Export contacts → a `.vcf` lands in Downloads and Google Contacts
  imports it.
- Open CONTROL → laptop panels appear and refresh.
- Turn off wifi → the "no internet — retry" screen shows, not a white page.
