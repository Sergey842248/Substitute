# Privacy Policy

**Last updated:** 2026-08-23

## 1. Overview

**Substitute** ("the App") is an open-source Flutter application that helps students, teachers, and schools view and manage substitution plans based on data provided by Indiware / Stundenplan24 (`stundenplan24.de`). The App is available as an Android app and an iPhone app.

This Privacy Policy explains what information the App processes, how it is used, and your choices. Because Substitute is a local-first application, it is designed to minimize data collection.

## 2. Data We Do Not Collect

Substitute does **not**:

- Use any third-party analytics, advertising, or tracking SDKs.
- Use Firebase, crash-reporting, or any remote analytics service.
- Collect or transmit personal data to the App developer or any server operated by the project.
- Require you to create an account with us.

There is no backend operated by the Substitute project. We do not store, process, or sell any personal information about you.

## 3. Data Stored Locally on Your Device

To function, the App stores the following information **locally** on your device using the platform's secure local storage (e.g. Android `SharedPreferences`):

- **School credentials:** Your school number and the login credentials (username and password) for the substitution plan provider (`stundenplan24.de`). These are stored only on your device and are used solely to authenticate requests to your school's substitution plan.
- **App preferences:** Your selected language, favorite classes, hidden courses, teacher mappings, and other settings.
- **Substitution plan data:** Cached substitution plans, teacher schedules, and room information downloaded from your school's provider.

This data never leaves your device except to communicate directly with the substitution plan provider you configure (see Section 4).

## 4. Data Shared With Third Parties

The App communicates only with the services you explicitly configure:

- **Stundenplan24 / Indiware (`stundenplan24.de`):** The App sends your school number and Basic Auth credentials over HTTPS to fetch your school's substitution plan data. This data sharing is necessary for the core functionality and is governed by your school's and Indiware's own privacy practices.
- **GitHub (`api.github.com`):** When checking for app updates, the App requests public release information from the official Substitute GitHub repository. No personal data is sent with this request.
- **QR code sharing (App-only):** You may optionally export your school/class login credentials as a QR code to share them with other people. This happens entirely on your device, and the shared credentials are only transmitted when you choose to display or share the code. Scanning a QR code (via the device camera) to import credentials is also processed locally.

We are not responsible for the privacy practices of Stundenplan24, Indiware, GitHub, or any school that provides substitution data.

## 5. Permissions

- **Internet:** Required to download substitution plans, check for updates, and open documentation links.
- **Camera (App-only):** Used only to scan QR codes for importing shared credentials. The camera is not used for any other purpose and no images are stored or transmitted.
- **Notifications:** With your permission, the App can send local notifications about changes to the substitution plan. These are generated on your device and do not involve a remote push server.


## 6. Children's Privacy

Substitute is intended for use by students and schools. It does not knowingly collect personal information from children beyond what is required to display the configured school's substitution plan. If you are a parent or guardian and have concerns, please review the credentials and data stored on the device.

## 7. Your Choices and Rights

- You can delete all locally stored data at any time by clearing the App's storage/data or uninstalling the App.
- You can disable background updates by restricting battery usage for the App in your device settings (`Apps > Substitute > Battery > Restricted`).
- You can revoke camera and notification permissions at any time through your device settings.

## 8. Changes to This Policy

We may update this Privacy Policy from time to time. Material changes will be reflected by updating the "Last updated" date above. The current version is always available in the project repository.

## 9. Contact

Substitute is an open-source project. If you have any questions about this Privacy Policy, please open an issue on the official GitHub repository:

https://github.com/Sergey842248/Substitute
