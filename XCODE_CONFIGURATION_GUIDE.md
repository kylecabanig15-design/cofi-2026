# iOS Xcode Configuration Checklist

## If You're Still Getting "Lost Connection to Device"

### Step 1: Verify Xcode Build Settings

Check that your iOS deployment target is correct:

```bash
# Navigate to iOS folder
cd ios

# Check deployment target from Podfile
grep "platform :ios" Podfile
# Should output: platform :ios, '15.0'

# Verify Runner target deployment target
open Runner.xcworkspace
# In Xcode: Select Runner target → Build Settings → iOS Deployment Target
# Should be 15.0 or lower (matches Podfile)
```

### Step 2: Check Pod Installation

```bash
cd ios

# Verify pods are installed correctly
pod deintegrate
pod install --repo-update

# If that fails, try:
rm Podfile.lock
pod install

cd ..
```

### Step 3: Clear Xcode Cache

```bash
# Reset Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Or just for this project
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

# Restart Xcode
```

### Step 4: Check Device Connection

```bash
# List all connected devices
flutter devices

# If simulator isn't showing:
xcrun simctl list

# Boot a simulator
xcrun simctl boot <device_udid>

# Or restart all
xcrun simctl erase all
```

### Step 5: Verbose Build

```bash
# See exactly where it's disconnecting
flutter run -v 2>&1 | tee build.log

# Search for errors
grep -i "error\|connection\|timeout" build.log
```

### Step 6: Check Runner Configuration

In Xcode (Runner.xcworkspace):
1. Select "Runner" project (not target)
2. Select "Runner" target
3. Go to "Build Settings"
4. Verify:
   - Minimum iOS Deployment Target: 15.0
   - Valid Architectures: arm64, arm64e (simulator: x86_64, arm64)
   - Signing: Team ID is set

### Step 7: Check Runner Build Phases

In Xcode:
1. Select "Runner" target
2. Go to "Build Phases"
3. Look for "Thin Binary" script
4. If there's a Swift code generation phase, verify it's not failing

### Step 8: Network/DNS Issues

If it's not Xcode:

```bash
# Check if Firebase is reachable
ping -c 3 firebase.google.com
ping -c 3 firebaseinstallations.googleapis.com

# Check DNS resolution
nslookup firebase.google.com
nslookup firebaseinstallations.googleapis.com

# If DNS fails, try changing device DNS to 8.8.8.8
```

### Step 9: Simulator vs Physical Device

**If using simulator:**
```bash
# Restart simulator
xcrun simctl shutdown all
xcrun simctl erase all
xcrun simctl boot <device_udid>

# Or just
open -a Simulator
```

**If using physical device:**
```bash
# Disconnect and reconnect
# Trust the device if prompted
# Restart Xcode
# In Xcode: Devices and Simulators → Unplug → Replug
```

### Step 10: Firebase Connection Test

Add this to your app temporarily to test Firebase connectivity:

```dart
import 'dart:io';

Future<bool> testFirebaseConnection() async {
  try {
    final result = await InternetAddress.lookup('firebase.google.com');
    print('Firebase reachable: ${result.isNotEmpty}');
    return result.isNotEmpty;
  } on SocketException catch (e) {
    print('Cannot reach Firebase: $e');
    return false;
  }
}

// Call this in main():
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final canReachFirebase = await testFirebaseConnection();
  print('Firebase connectivity: $canReachFirebase');
  // Continue...
}
```

## Common Xcode Issues

| Issue | Solution |
|-------|----------|
| Pod installation fails | Run `pod repo update` first |
| Build takes forever | Clear DerivedData and rebuild |
| "Missing file" errors | Run `flutter pub get` and `flutter pub upgrade` |
| Simulator not connecting | Restart Xcode and simulator completely |
| Device asks to trust | Tap Trust on device, restart Xcode |
| Architecture mismatch | Check build architecture settings |

## Quick Nuclear Option (Reset Everything)

```bash
# WARNING: This removes everything and rebuilds from scratch
flutter clean
rm -rf ios/Pods ios/Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData
flutter pub get
cd ios
pod deintegrate
pod install --repo-update
cd ..
flutter run
```

## Modified Files
- `/lib/main.dart` - Already has timeout handling to prevent Firebase hangs

## Next: Test Each Layer

1. **Can Xcode build?** → `flutter run -v` should show Swift/Objective-C errors if no
2. **Can device connect?** → `flutter devices` should list it
3. **Can Firebase connect?** → App should show splash screen even if Firebase fails
4. **Can app run?** → `flutter run` should show your app on device/simulator

If any of these fail, report which one and the specific error message.
