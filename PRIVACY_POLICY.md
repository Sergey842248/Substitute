# Privacy Policy

**Last updated:** 2026-09-30

## 1. Overview

**Substitute** ("the App") is an open-source Flutter application that helps students, teachers, and schools view and manage substitution plans based on data provided by Indiware / Stundenplan24 (`stundenplan24.de`). The App is available as an Android app and an iPhone app.

This Privacy Policy explains what information the App processes, how it is used, and your choices. Because Substitute is a local-first application, it is designed to minimize data collection.

## 2. Data We Do Not Collect

Substitute does **not**:

- Use any third-party analytics, advertising, or tracking SDKs.
- Use Firebase, crash-reporting, or any remote analytics service.
- Collect or transmit personal data to the App developer or any server operated by the project.
- Require you to create an account with us.

We do not store, process, or sell any personal information about you.

The App has **no account system**. The optional sync and share features
(Section 5) use a code of ten random words that only your device knows; no
account is created, and no email address, real name, or phone number is ever
transmitted.

## 3. Data Stored Locally on Your Device

To function, the App stores the following information **locally** on your device using the platform's secure local storage (e.g. Android `SharedPreferences`):

- **School credentials:** Your school number and the login credentials (username and password) for the substitution plan provider (`stundenplan24.de`). These are stored only on your device and are used solely to authenticate requests to your school's substitution plan.
- **App preferences:** Your selected language, favorite classes, hidden courses, teacher mappings, and other settings.
- **Substitution plan data:** Cached substitution plans, teacher schedules, and room information downloaded from your school's provider.

This data never leaves your device except to communicate directly with the
substitution plan provider you configure (see Section 4), and -- if you
explicitly switch on sync or create a share -- with the sync server
(see Section 5).

## 4. Data Shared With Third Parties

The App communicates only with the services you explicitly configure:

- **Stundenplan24 / Indiware (`stundenplan24.de`):** The App sends your school number and Basic Auth credentials over HTTPS to fetch your school's substitution plan data. This data sharing is necessary for the core functionality and is governed by your school's and Indiware's own privacy practices.
- **GitHub (`api.github.com`):** When checking for app updates, the App requests public release information from the official Substitute GitHub repository. No personal data is sent with this request.
- **QR code sharing (App-only):** You may optionally export your school/class login credentials as a QR code to share them with other people. This happens entirely on your device, and the shared credentials are only transmitted when you choose to display or share the code. Scanning a QR code (via the device camera) to import credentials is also processed locally.

We are not responsible for the privacy practices of Stundenplan24, Indiware, GitHub, or any school that provides substitution data.

## 5. Sync and Share (Optional)

The App offers two **optional** features that move data between devices:
**Sync** keeps your own devices up to date, **Share** hands selected classes
and persons to colleagues. Both are switched off until you turn them on, and
both work the same way: **your device encrypts the data before sending it.**

### The sync server

- **Address:** `https://socgdoyooyiupnmzuaox.supabase.co`
- **Source code:** <https://github.com/Sergey842248/Substitute/tree/main/supabase/functions>
- **Database schema:** <https://github.com/Sergey842248/Substitute/tree/main/docs/server-supabase>

### What is transmitted, and in what form

| | Sent in plain text | Encrypted end-to-end |
|---|---|---|
| **Sync** | A random device name and a timestamp | Classes, persons, courses, saved plans, and -- if you enable it -- settings |
| **Share** | A username, your school number, a display name of your choice, and the flags "searchable" and "global" | The selected classes, persons, and plans |
| **Search directory** | The display names of people who marked a share as searchable, for your school number only | Everything contained in the shares |

The server stores and forwards the encrypted envelopes **without being able to
read them** -- not even the operator of the server can decrypt your data. The
only unencrypted parts are the entries in the table above, which are needed
for the search menu to work at all.

### What is never transmitted

- **Your school number, username, and password** are never sent to the sync
  server. They are used only to talk to `stundenplan24.de`.
- **Credentials are never part of a sync chain or a share**, even when you
  include settings.
- No analytics, no tracking, no profiling.

### The search menu

If you mark a share as **searchable**, colleagues at the **same school
number** can find your display name in the app and choose from your shares.
People from other schools cannot see you there, and a share you have not
marked as searchable never appears. Display names are checked, and offensive
names are rejected.

You can make a share **global**, which means teachers at other schools can
open it if they know your username. A global share still does not appear in
other schools' search menus.

You can protect a share with a **password** (ten words). Once a password is
set, neither the username alone nor the school credentials can open it.

### Leaving and deleting

- **Leaving a sync** keeps all of your data on your device. It only stops
  keeping it in step with the other devices.
- **Deleting a share** makes it unreachable for others. Data that others have
  already imported stays on their devices.
- **Deleting a sync** removes the sync code from the server. Other devices
  keep their data but can no longer sync.

### What the server operator can and cannot do

The operator of the sync server can **delete** stored data. Because of the
end-to-end encryption, the operator can **not** read it, back it up in a
usable form, or restore it. It is only accessible to the devices that hold
the matching ten-word code.

### Status page

The status page hosted on GitHub Pages (`sergey84224.github.io/Substitute`)
requests `GET /v1/health` from the sync server in order to show either
"Server is running" or "Server is stopped". No data about you is sent or
stored by that page.

## 6. Permissions

- **Internet:** Required to download substitution plans, check for updates, and open documentation links.
- **Camera (App-only):** Used only to scan QR codes for importing shared credentials. The camera is not used for any other purpose and no images are stored or transmitted.
- **Notifications:** With your permission, the App can send local notifications about changes to the substitution plan. These are generated on your device and do not involve a remote push server.


## 7. Children's Privacy

Substitute is intended for use by students and schools. It does not knowingly collect personal information from children beyond what is required to display the configured school's substitution plan. If you are a parent or guardian and have concerns, please review the credentials and data stored on the device.

## 8. Your Choices and Rights

- You can delete all locally stored data at any time by clearing the App's storage/data or uninstalling the App.
- You can switch sync on and off at any time, and decide whether settings are included.
- You can leave a sync at any time without losing data.
- You can delete a share at any time; it then becomes unreachable for others.
- You can decide for each share whether it is searchable, global, and password-protected.
- You can disable background updates by restricting battery usage for the App in your device settings (`Apps > Substitute > Battery > Restricted`).
- You can revoke camera and notification permissions at any time through your device settings.

## 9. Changes to This Policy

We may update this Privacy Policy from time to time. Material changes will be reflected by updating the "Last updated" date above. The current version is always available in the project repository.

## 10. Contact

Substitute is an open-source project. If you have any questions about this Privacy Policy, please open an issue on the official GitHub repository:

https://github.com/Sergey842248/Substitute
