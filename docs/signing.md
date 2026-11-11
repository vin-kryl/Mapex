# Android signing key

Sortle uses **Play App Signing**. Google keeps the key that signs the app
people download. We keep only an **upload key**, which proves an upload came
from us. If the upload key is ever lost, Google can reset it from the Play
Console, so a lost key does not mean a lost app.

The key file and its password are never committed. `android/key.properties`,
`*.jks` and `*.keystore` are in `.gitignore`.

## Where things live

| What | Where |
| --- | --- |
| Upload key file | `~/Keys/sortle-upload.jks` on Vineet's Mac |
| Backup of the key file | Attached to the "Sortle upload key" entry in Vineet's password manager |
| Key password | Same password manager entry |
| Build settings that point at the key | `android/key.properties` in the project folder on the Mac (not in git) |

## Make the key (once)

1. Open **Terminal** (press Cmd + Space, type `Terminal`, press Enter).
2. Paste this line and press Enter. It makes a folder for keys, outside the
   project:

   ```sh
   mkdir -p ~/Keys
   ```

3. Paste this line and press Enter. It uses the Java that comes with Android
   Studio:

   ```sh
   "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -genkeypair -v -keystore ~/Keys/sortle-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

4. It asks for a **keystore password**. Make up a strong one, type it and
   press Enter. Nothing shows on screen while you type; that is normal. Type
   it again when asked.
5. It asks for your name, organisation, city and so on. Fill them in or press
   Enter to skip each one. When it asks `Is CN=... correct?`, type `yes` and
   press Enter.
6. Open your password manager and make a new entry called
   **Sortle upload key**. Put the password in it.
7. In the same entry, attach the file `sortle-upload.jks`. To find it, in
   Finder press Cmd + Shift + G, type `~/Keys` and press Enter.

## Let GitHub sign the APKs (once)

The Release workflow signs the Android APK with the upload key, so every
download is signed with the same key and updates install over the old
version. GitHub keeps the key as two encrypted secrets that nobody can read
back.

1. In Terminal, paste this and press Enter. It copies the key file to the
   clipboard as text:

   ```sh
   base64 -i ~/Keys/sortle-upload.jks | pbcopy
   ```

2. Open https://github.com/vin-kryl/Sortle/settings/secrets/actions/new
3. Name: `ANDROID_KEYSTORE`. Secret: press Cmd + V. Click **Add secret**.
4. Open the same link again. Name: `ANDROID_KEYSTORE_PASSWORD`. Secret: the
   password from the password manager. Click **Add secret**.

The key alias is `upload`, and the key password is the same as the keystore
password, which is how `keytool` makes it.

## Use the key for a Play build (at release time)

1. In the project folder on the Mac, open the `android` folder.
2. Make a new text file there named exactly `key.properties` with these four
   lines. Replace `PASSWORD` with the password from step 4 (twice) and
   `YOURNAME` with your Mac user name:

   ```properties
   storePassword=PASSWORD
   keyPassword=PASSWORD
   keyAlias=upload
   storeFile=/Users/YOURNAME/Keys/sortle-upload.jks
   ```

3. Build with `flutter build appbundle --release`. The signed file is at
   `build/app/outputs/bundle/release/app-release.aab`.
4. In the Play Console, create the app and upload that `.aab`. Leave
   **Play App Signing** switched on (it is on by default).

Without `key.properties`, release builds fall back to the debug key so CI can
still check that the app builds. Those builds cannot be uploaded to Play.

## If the key is lost

Restore `sortle-upload.jks` from the password manager. If the backup is gone
too, ask Google for an upload key reset in the Play Console under
**Setup → App signing**.
