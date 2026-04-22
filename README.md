# Samsung Tab S9 FE Debloater

Reusable ADB-based debloat script for a Samsung Galaxy Tab S9 FE on stock One UI.

The default profile follows a specific goal:

- degoogle the owner profile
- remove Microsoft apps
- remove Bixby and a large chunk of Samsung telemetry/background extras
- keep core tablet functionality working
- keep work-profile plumbing intact for a future Shelter/Insular-style setup

## Safety model

The script only removes packages with:

```bash
adb shell pm uninstall -k --user 0 <package>
```

It does not use root and it does not touch the core packages below even if they appear in a profile:

- `android`
- `com.android.systemui`
- `com.samsung.android.systemui`
- `com.sec.android.app.launcher`
- `com.samsung.android.spen`
- camera / Smart Capture dependencies
- S Pen / Air Command packages
- work-profile provisioning packages

## Included profile

- `profiles/owner-degoogle-work-profile-ready.txt`

This profile is based on a real Tab S9 FE pass and is intended to preserve:

- launcher and UI
- Samsung camera
- My Files
- Samsung Notes
- Samsung keyboard
- S Pen features
- managed provisioning / work profile support

## Usage

Run the default profile:

```bash
./scripts/debloat.sh apply
```

Run a specific profile:

```bash
./scripts/debloat.sh apply profiles/owner-degoogle-work-profile-ready.txt
```

Restore one package:

```bash
./scripts/debloat.sh restore com.google.android.gms
```

Restore an entire profile:

```bash
./scripts/debloat.sh restore-file
```

Install Shelter and start managed-profile provisioning:

```bash
./scripts/setup-shelter.sh
```

Notes:

- The script is idempotent.
- If Shelter is already installed, it will not reinstall it.
- If a managed profile already exists, it will not try to create another one.
- Profile creation still requires approval on the tablet screen.

## Device requirements

1. Install `adb`
2. Enable Developer Options on the tablet
3. Enable `USB debugging`
4. Connect the tablet and accept the RSA prompt
5. Verify `adb devices` shows the device as `device`

If ADB shows `unauthorized`, accept the prompt on the tablet first.

## Notes

- Samsung may block removal of some packages such as `com.samsung.android.themecenter` or `com.samsung.android.fmm`.
- Missing packages are skipped and reported.
- Failures do not stop the whole run.

## Work profile strategy

If your goal is GrapheneOS-like separation:

1. Keep the owner profile degoogled.
2. Create a work profile with Shelter, Insular, or another managed-profile tool.
3. Install banking apps and Google Maps in that work profile.
4. Add Google dependencies there only if those apps require them.

## Shelter setup helper

`scripts/setup-shelter.sh` does the following:

- verifies `adb` and an authorized device
- downloads Shelter from F-Droid if needed
- installs Shelter if missing
- checks whether a managed work profile already exists
- starts Android's managed-profile provisioning flow if absent
- verifies the final user / profile state

It does not use root.

## Inspiration

- `khlam/debloat-samsung-android`
- `mendel5/remove-samsung-bloatware`

This repo is more conservative about keeping Samsung work-profile support and feature-critical packages intact.
