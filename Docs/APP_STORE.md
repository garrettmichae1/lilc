# App Store Connect remaining (lilC 0.1.0)

In-repo. Does not replace App Store Connect. Use this while uploading the first build.

## Already in the binary / repo

- Bundle display name: lilC
- Version: 0.1.0
- Encryption: `ITSAppUsesNonExemptEncryption = false`
- Privacy and Terms HTTPS:
  - https://garrettmichae1.github.io/lilc/privacy.html
  - https://garrettmichae1.github.io/lilc/terms.html
- Support: mailto:support@lilc.app
- No account. C stays free. Optional Linux course IAP (`lilc.linux.course`) when shown. Agent UI hidden
- PicoC is an interpreter, not GCC — keep that wording in the description

## Connect-only (cannot finish from git)

1. Sign in at https://appstoreconnect.apple.com with the Apple Developer account.
2. Create the iOS app if it does not exist. Bundle ID in the project is `lilC` — confirm it matches the App ID in the developer portal (reverse-DNS such as `app.lilc` is typical if you still need to register one).
3. Upload a Release build from Xcode (Organizer → Distribute) or `xcodebuild -scheme lilC -configuration Release`.
4. Age rating questionnaire.
5. App Privacy nutrition labels (data not collected).
6. Screenshots. Minimum for iPhone:
   - 6.7" (iPhone 16 Pro Max / 17 Pro Max class): home, editor + hello world output, syntax error / jump-to-error, Settings Light, Settings Dark
   - 6.1" (iPhone 16 / 17 class): the same five frames
   - Optional iPad if the record includes iPad
7. Description, subtitle, keywords. Honest only: free C learner, PicoC, not GCC, no AI in this release.
8. Support URL: https://garrettmichae1.github.io/lilc/
9. Marketing URL (optional): https://garrettmichae1.github.io/lilc/web/
10. Review notes: no demo account. Open editor → RUN on the starter `hello.c`. Agent is hidden. There is no C Manual and no remote VM.

## Screenshot checklist

- [ ] Home (Light)
- [ ] Home (Dark)
- [ ] Editor with hello world output
- [ ] Friendly syntax error + ERROR jump
- [ ] Settings PicoC note + legal links
- [ ] Caption text does not say GCC, compiler toolchain, AI, or Linux VM
