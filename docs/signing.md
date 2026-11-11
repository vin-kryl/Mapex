# Android signing key

Sortle is shared as an APK on GitHub Releases, not through Google Play. The
Release workflow signs every APK with one key, `sortle-upload.jks`. Android
only installs an update over the old app if both were signed with the same
key, so **this key cannot be replaced**. If it is lost, everyone has to
uninstall Sortle (losing the boards on their phone unless they exported them)
and install it again. Keep the backup safe.

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

## Building a signed APK on the Mac (optional)

The Release workflow does this for you. To do it by hand, make
`android/key.properties` (never commit it) with these four lines, replacing
`PASSWORD` and `YOURNAME`:

```properties
storePassword=PASSWORD
keyPassword=PASSWORD
keyAlias=upload
storeFile=/Users/YOURNAME/Keys/sortle-upload.jks
```

Then run `flutter build apk --release`. Without `key.properties`, builds use
the debug key, which is fine for checking that the app builds but not for
sharing.

If Sortle goes on Google Play later, turn on **Play App Signing** there and
upload with this same key.

## If the key is lost

Restore `sortle-upload.jks` from the password manager. There is no other way
to get it back.
