# SVSystem App Development Rules

These rules apply to every independent utility app in this repository.

## 1. App identity and branding
- Every app must have its own tool-specific app logo/icon combined with the SVSystem brand identity.
- Every app must include a branded splash screen and clear "by SVSystem" attribution.
- Keep the shared SVSystem visual system consistent across apps (blue, navy, white and yellow), while making each tool icon recognizable.

## 2. Monetization by default
- Integrate AdMob into every app where ads make sense and do not damage the core user experience.
- Consider suitable ad formats: banner, app-open, interstitial and rewarded. Choose placements and frequency limits based on the app's actual user flow; never show several disruptive ads immediately at launch.
- Add a premium subscription or one-time premium purchase where the app has meaningful premium value. Do not force an artificial subscription into a simple tool that has no ongoing premium benefit.
- Use Google test ad IDs during development. Switch to the owner's verified production IDs only before release.
- Implement purchase restore, entitlement checks and server-side/purchase verification as appropriate before selling premium access.
- Follow Google Play and AdMob policies, consent/privacy requirements, and disclose ads and subscriptions accurately.

## 3. Git branch strategy
- Keep `main` as the stable integration branch.
- Develop each app on its own branch created from `main`, using names such as `app/image-compressor`, `app/qr-generator`, and `app/pdf-tools`.
- Keep app-specific code and build changes on that app's branch. Merge back to `main` only after the app passes the release-readiness checklist.
- Shared package changes must be compatible with existing apps and should be tested before merging.

## 4. Build-efficiency target
- Aim to complete each app in no more than 2–3 Codemagic build attempts:
  1. First build: resolve dependencies, analyze and compile; fix all discovered issues.
  2. Second build: verify release APK/AAB, app icon, splash screen, permissions and core flows.
  3. Third build (only if needed): final fixes and release verification.
- Reduce avoidable builds by reviewing code, manifests, package versions and configuration before starting a build.
- This is a delivery target, not a guarantee; never skip testing or policy/security work just to meet the build count.

## 5. Play Store release-ready definition
Before calling an app complete, verify:
- Unique application ID, app title, launcher icon, branded splash screen and SVSystem attribution.
- Core tool functionality works on a real Android device, including error and empty states.
- Responsive UI, permissions and Android lifecycle behavior are checked.
- Ads use production IDs only after account/app setup; test IDs are never shipped as a monetized release.
- Premium flow, restore purchases, entitlement handling and purchase verification work if premium is offered.
- Privacy policy, Data safety declarations, ads declaration, subscription disclosures and other Play Console requirements are accurate.
- Release AAB is signed with a secure upload key; secrets and keystores are never committed to Git.
- Store listing assets, screenshots, description, content rating and target audience declarations are prepared.
- No critical analyzer errors, crashes, broken links or placeholder content remain.

## 6. Product principle
Build small, genuinely useful, focused standalone apps. Prefer a reliable, polished tool over adding features only to increase app count or ad impressions.
