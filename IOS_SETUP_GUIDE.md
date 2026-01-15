# iOS Google Sign-In Setup Guide

## Step 1: Get Your iOS Bundle ID

Your iOS bundle ID is: `com.example.cofi`

To verify/change it:
1. Open `ios/Runner.xcodeproj` in Xcode
2. Select "Runner" in the project navigator
3. Go to Build Settings > Signing & Capabilities
4. Check the Bundle Identifier

## Step 2: Configure Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (likely the one with your Android app)
3. Go to **APIs & Services > Credentials**
4. Look for or create an OAuth 2.0 Client ID for iOS:
   - Click **Create Credentials > OAuth client ID**
   - Choose **iOS**
   - Enter Bundle ID: `com.example.cofi`
   - Download the plist file (usually named `GoogleService-Info.plist`)

## Step 3: Add GoogleService-Info.plist to Xcode

1. Download the `GoogleService-Info.plist` from Google Cloud Console
2. Drag and drop it into Xcode under `ios/Runner/`
3. Make sure it's added to the Runner target
4. The file should be at: `ios/Runner/GoogleService-Info.plist`

## Step 4: Update Info.plist URL Scheme

The Info.plist has been updated with a URL scheme placeholder. You need to replace `YOUR_CLIENT_ID` with your actual Google Client ID:

1. Find your Client ID in the `GoogleService-Info.plist` file (look for `CLIENT_ID` key)
2. Update `ios/Runner/Info.plist`:
   - Find the `CFBundleURLSchemes` section
   - Replace `com.googleusercontent.apps.YOUR_CLIENT_ID` with the actual ID
   - Example: `com.googleusercontent.apps.123456789-abc1def2ghi3jkl4mno5pqr6stu7vwx.apps.googleusercontent.com`

## Step 5: Build and Run on iOS

```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Run on iOS simulator
flutter run -d "iPhone 15"

# Or run on physical device
flutter run
```

## Step 6: Test Google Sign-In on iOS

1. Launch the app on iOS
2. Go to Login screen
3. Tap "Continue with Google"
4. Complete the Google authentication flow
5. You should be routed to:
   - AccountTypeSelectionScreen (new user)
   - InterestSelectionScreen (if accountType is set)
   - HomeScreen/ExploreFeed (if profile is complete)

## Troubleshooting

**Issue: "The app is not registered in Google Console"**
- Solution: Make sure your iOS Bundle ID in Xcode matches exactly what you registered in Google Cloud Console

**Issue: Google Sign-In won't open**
- Solution: Ensure `GoogleService-Info.plist` is properly added to Xcode target
- Check that the URL scheme in Info.plist is correct

**Issue: "Configuration error"**
- Solution: Delete `GoogleService-Info.plist` and re-download from Google Cloud Console
- Run `flutter clean && flutter pub get`

## Files Modified for iOS Setup

- ✅ `ios/Runner/Info.plist` - Added URL schemes for Google Sign-In
- ✅ `ios/Podfile` - Already configured (no changes needed)
- ⏳ `ios/Runner/GoogleService-Info.plist` - You need to add this file manually

## Next Steps

1. Download `GoogleService-Info.plist` from Google Cloud Console
2. Add it to `ios/Runner/` in Xcode
3. Update the CLIENT_ID in the URL scheme in Info.plist
4. Run `flutter run` to test on iOS
