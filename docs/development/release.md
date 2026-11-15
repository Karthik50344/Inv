# Release Checklist (Phase 12)

- [ ] `dart format --set-exit-if-changed .`, `flutter analyze` clean, all tests green
- [ ] Android: app icon, splash, signing config, `flutter build appbundle --release`
- [ ] iOS (macOS required): icon, splash, bundle ID `com.rk.inventrix`, `flutter build ipa`
- [ ] Permissions reviewed (storage/file access only as needed); privacy statement (all data local)
- [ ] Backup/restore verified on physical devices
- [ ] Tax behaviour reviewed for the target jurisdiction
