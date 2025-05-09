# Development Guide

This project uses Git submodules to manage the Rust native library alongside the Flutter application. Follow these instructions to set up your development environment and work with both codebases.

## Initial Setup

Clone the repository with its submodules:

```bash
# Clone the repository including submodules
git clone --recursive https://github.com/yourusername/activity-monitor-app.git

# Navigate to the project directory
cd activity-monitor-app
```

If you've already cloned the repository without `--recursive`, initialize and update the submodules:

```bash
git submodule init
git submodule update
```

## Project Structure

- `lib/` - Flutter application code
- `rust_lib/` - Rust native library (submodule)
- `windows/` - Windows-specific configuration
- `macos/` - macOS-specific configuration

## Development Workflow

### Making Changes to the Rust Library

1. Navigate to the Rust submodule:
   ```bash
   cd rust_lib
   ```

2. Make your changes to the Rust code

3. Build and test the library:
   ```bash
   cargo build
   cargo test
   ```

4. Commit and push your changes:
   ```bash
   git add .
   git commit -m "Description of changes"
   git push origin main
   ```

5. Update the Flutter repository to use the new version:
   ```bash
   cd ..  # Back to the Flutter repository root
   git add rust_lib  # Stage the submodule reference update
   git commit -m "Update Rust library submodule"
   git push
   ```

### Making Changes to the Flutter App

1. Make your changes to the Flutter code in the `lib/` directory

2. Test the app with the current Rust library:
   ```bash
   flutter run
   ```

3. Commit and push your changes:
   ```bash
   git add .
   git commit -m "Description of changes"
   git push
   ```

## Updating the Rust Submodule to Latest Version

To update the Rust submodule to the latest version:

```bash
cd rust_lib
git pull origin main
cd ..
git add rust_lib
git commit -m "Update Rust library to latest version"
git push
```

## Building Releases

The GitHub Actions workflow will automatically build both macOS and Windows versions when changes are pushed to the main branch. The workflow:

1. Builds the Rust library for both platforms
2. Integrates the libraries with the Flutter app
3. Creates platform-specific installers
4. Uploads artifacts that can be downloaded from the GitHub Actions page

## Local Cross-Platform Development

### For macOS Development:
```bash
# Build Rust library
cd rust_lib
cargo build --release
cd ..

# Copy dylib to the correct location
mkdir -p macos/Libraries
cp rust_lib/target/release/libactivity_monitor.dylib macos/Libraries/

# Run Flutter app
flutter run -d macos
```

### For Windows Development:
```bash
# On a Windows machine:

# Build Rust library
cd rust_lib
cargo build --release
cd ..

# Copy DLL to the correct location
mkdir -p windows/lib
cp rust_lib/target/release/activity_monitor.dll windows/lib/

# Run Flutter app
flutter run -d windows
```

## Troubleshooting

### Submodule Issues

If you encounter issues with the submodule, try:

```bash
git submodule sync
git submodule update --init --recursive --force
```

### Building on macOS

If you encounter permission issues on macOS, ensure your app has the required entitlements:

- Open the project in Xcode: `open macos/Runner.xcworkspace`
- Set the signing team
- Enable hardened runtime
- Add the Input Monitoring entitlement

### Building on Windows

If you encounter issues with the Windows build:

- Ensure you're running as administrator
- Check that the DLL is correctly placed in `windows/lib/`
- Verify the CMakeLists.txt has the correct paths
