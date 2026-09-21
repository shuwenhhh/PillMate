# Pillmate Onboarding Pages 1–3 — Design QA

- Source visual truth: `/var/folders/z_/l_zb6spj6f3fxfgn8ncv71cm0000gn/T/codex-clipboard-327f3fe7-6588-4ecc-a337-c00530b34def.png`
- Page-two source: `/var/folders/z_/l_zb6spj6f3fxfgn8ncv71cm0000gn/T/codex-clipboard-ab7e2e86-b30a-4b2d-ba20-5012a317fd89.png`
- Page-three source: `/var/folders/z_/l_zb6spj6f3fxfgn8ncv71cm0000gn/T/codex-clipboard-8ad45a30-9e0f-4876-8668-529b4cbe01ec.png`
- Implementation screenshot: `/tmp/pillmate-onboarding-final.png`
- Page-two implementation: `/tmp/pillmate-onboarding-page2-final.png`
- Side-by-side comparison: `/tmp/pillmate-onboarding-final-comparison.png`
- Page-two comparison: `/tmp/pillmate-onboarding-page2-final-comparison.png`
- Page-three implementation: `/tmp/pillmate-onboarding-page3-final.png`
- Page-three comparison: `/tmp/pillmate-onboarding-page3-comparison.png`
- Viewport: iPhone 17 Pro simulator, 402 × 874 points, light appearance
- Pixels and normalization: source 492 × 1065 px; implementation 1206 × 2622 px at 3×. The implementation was normalized to 492 × 1064 px for the 984 × 1065 px side-by-side comparison.
- State: first launch, Welcome page, no error message

## Full-view comparison evidence

The final comparison preserves the reference hierarchy and rhythm: compact Pillmate lockup, two-line rounded display headline, two-line supporting copy, centered glass jar illustration, three-star page marker, one primary CTA, one secondary action, and quiet legal links. The native iOS status bar adds the expected platform-safe-area offset. The reference's Get started / Log in controls are intentionally replaced by the requested official Continue with Apple / Maybe later controls.

## Required fidelity surfaces

- Fonts and typography: SF Rounded is used consistently. Weight, two-line wrapping, and dark-plum hierarchy closely match the source. The Apple label is system-owned as required.
- Spacing and layout rhythm: 30-point side margins, headline spacing, illustration scale, page marker, CTA, and footer follow the source proportions while respecting the iPhone safe area.
- Colors and visual tokens: the pale lavender-white background, deep plum headline, muted purple support copy, yellow accent stars, and black Apple CTA match the reference palette and platform requirement.
- Image quality and asset fidelity: the hero is a dedicated high-resolution transparent PNG generated from the source art direction. Glass edges, yellow stars, blush, and facial expressions remain sharp at 3× rendering.
- Copy and content: required Welcome copy is exact. Primary, secondary, privacy, and terms labels match the product brief with no duplicate Log in / Get started actions.

Focused region crops were not needed: at the normalized 984 × 1065 comparison size, the logo, type, illustration edges, controls, and footer labels are all clearly readable and judgeable.

## Findings

- No actionable P0/P1/P2 visual mismatches remain.
- P3: the reference contains extra handwritten hearts, rays, and “Small steps brighter days” doodles. The final transparent asset keeps the cleaner jar-and-stars composition described in the brief; these decorations can be added later without changing layout.

## Comparison history

1. Initial implementation evidence: `/tmp/pillmate-onboarding-v1-ready.png` and `/tmp/pillmate-onboarding-comparison.png`.
   - P2: the jar was about 10% smaller than the source and the page marker/CTA sat too high.
   - Fix: increased the hero slot from 41% to 45% of available height and increased the marker's top separation from 2 to 24 points.
2. Post-fix evidence: `/tmp/pillmate-onboarding-final.png` and `/tmp/pillmate-onboarding-final-comparison.png`.
   - Result: the hero, marker, and CTA now align with the source's major-region proportions; no P0/P1/P2 findings remain.

## Implementation checklist

- [x] First-launch Welcome route
- [x] Official Sign in with Apple component
- [x] Quiet cancellation and short failure state
- [x] Existing-profile vs new-profile routing
- [x] Guest continuation
- [x] Navigable Privacy Policy and Terms of Use pages
- [x] Responsive scrolling on compact heights
- [x] Functional nickname input, return-key submission, Skip, Back, and Continue actions
- [x] Xcode simulator build and launch verification

## Page-two full-view comparison evidence

The privacy-preferences page preserves the reference structure: native circular back control, character-and-heart hero, two-line display heading, one-line supporting copy, translucent analytics card with a real Toggle, centered legal links, second-page star marker, and full-width lavender CTA. The iOS status bar accounts for the expected vertical safe-area offset; after normalization, the app-owned regions align with the source composition.

### Page-two required fidelity surfaces

- Fonts and typography: rounded display and body styles reproduce the source hierarchy and line wrapping; the analytics title stays on one line and its description on two lines.
- Spacing and layout rhythm: the final 30%-height hero slot and compact analytics card keep the complete CTA visible in one screen on iPhone 17 Pro.
- Colors and visual tokens: cream, lavender, yellow, deep plum, translucent white, and the purple CTA follow the source palette.
- Image quality and asset fidelity: the hero is a dedicated 1402 × 1122 transparent PNG with clean alpha, generated from the selected source and background-extracted before use.
- Copy and content: all visible page-two text matches the supplied design. Terms and Privacy navigate to the same real in-app legal pages as Welcome.

### Page-two comparison history

1. Initial evidence: `/tmp/pillmate-onboarding-page2-v1.png` and `/tmp/pillmate-onboarding-page2-v1-comparison.png`.
   - P2: oversized hero/title/card caused the Save preferences button to fall below the safe visible area; analytics copy wrapped to three lines.
   - Fix: reduced the hero slot from 34% to 30%, adjusted display type from 40 to 36 points, compressed vertical gaps, and tightened the card to a one-line title/two-line description.
2. Post-fix evidence: `/tmp/pillmate-onboarding-page2-final.png` and `/tmp/pillmate-onboarding-page2-final-comparison.png`.
   - Result: all required content is visible without scrolling and no P0/P1/P2 visual mismatches remain.

## Page-three full-view comparison evidence

The nickname page preserves the selected source structure: circular back action and Skip at the top, a smiling yellow star peeking over a real text field, two-line rounded headline, supporting line, third-page star marker, and a full-width lavender Continue button. The final comparison places the 492 × 1065 source beside the simulator capture normalized to the same pixel dimensions. The implementation's expected iOS status bar shifts app-owned content downward while maintaining the source's internal spacing and hierarchy.

### Page-three required fidelity surfaces

- Fonts and typography: SF Rounded reproduces the source's heavy two-line display heading, medium support copy, field label, placeholder, navigation label, and CTA hierarchy without truncation.
- Spacing and layout rhythm: the illustration and hands overlap the input border correctly; the compact 104-point field restores the source's field-to-heading gap; the page marker and CTA remain anchored near the bottom safe area.
- Colors and visual tokens: pale lavender-white background, dark-plum type, light-purple border, golden selected star, and lavender CTA match the established onboarding palette.
- Image quality and asset fidelity: `NicknameStar` is a dedicated 1774 × 887 transparent PNG. It includes the warm cream shape, round yellow star, hands, blush, purple rays, heart, and “hello!” lettering without baking any UI controls into the raster.
- Copy and content: Nickname, Your name, What should we call you?, A little hello, just for you., Skip, and Continue match the selected design exactly.

Focused region crops were not needed because the normalized side-by-side evidence keeps the field typography, illustration alpha edges, hand overlap, navigation controls, page marker, and CTA clearly readable.

### Page-three interaction verification

- The field uses native `TextField` behavior, nickname content type, focus tint, and Continue keyboard submission.
- Tapping an empty Continue focuses the field instead of silently advancing.
- A non-empty nickname is trimmed, persisted through the existing binding, and completes onboarding.
- Skip completes onboarding without requiring a nickname; Back returns to page two without discarding the binding.
- The full page remains scrollable when the keyboard or a compact-height device reduces available space.

### Page-three comparison history

1. Initial evidence: `/tmp/pillmate-onboarding-page3-v1.png`.
   - P2: the generated character/input group and headline sat too low relative to the reference, and the field was taller than the source.
   - Fix: moved the hero group upward, reduced its reserved height from 335 to 295 points, moved the field overlap from 205 to 185 points, and reduced field height from 128 to 104 points.
2. Post-fix evidence: `/tmp/pillmate-onboarding-page3-final.png` and `/tmp/pillmate-onboarding-page3-comparison.png`.
   - Result: after accounting for native status-bar safe area, the hero, input, heading, marker, and CTA follow the source proportions with no actionable P0/P1/P2 mismatch.

## Personalized Home redesign — Design QA

- Source visual truth: `/var/folders/z_/l_zb6spj6f3fxfgn8ncv71cm0000gn/T/codex-clipboard-7c5c0ed8-fe1b-4b16-be82-c38fbd4317f1.png`
- Implementation screenshot: `/tmp/pillmate-home-redesign-final.png`
- Side-by-side comparison: `/tmp/pillmate-home-redesign-comparison.png`
- Viewport: iPhone 17 Pro simulator, 402 × 874 points, light appearance
- Pixels and normalization: source 853 × 1844 px; implementation 1206 × 2622 px at 3×. The implementation was normalized to 853 × 1844 px and appended beside the source.
- State: Tuesday, September 15, 2026; evening greeting; preview nickname “Misaki”; two completed doses and active Today tab. The source uses Monday, September 14 and three completed doses, so date and completion-count differences are intentional live-data differences.

### Full-view comparison evidence

The final comparison preserves the reference hierarchy: personalized rounded greeting, supporting health message, centered animated glass reward jar over a cream-and-lavender illustration, one-line medications heading with full date, compact white dose cards, state badges, and a floating five-item tab bar. Native iOS status-bar space accounts for the expected top offset.

### Required fidelity surfaces

- Fonts and typography: SF Rounded provides the heavy friendly display and card type. The greeting uses a one-line adaptive scale so “Good Evening, Misaki” stays intact; the medication heading was locked to one line after the first comparison.
- Spacing and layout rhythm: 18-point page margins, 270-point hero region, 82-point dose cards, 11-point card gaps, 22-point radii, and the floating bottom navigation follow the source proportions while leaving the list scrollable for live medication counts.
- Colors and visual tokens: deep plum text, muted lavender secondary copy, pale lavender background, translucent white cards, saturated purple completion marks, and warm cream hero glow match the selected target.
- Image quality and asset fidelity: the existing high-resolution glass and animated round-star assets remain functional. `HomeJarBackdrop` is a dedicated 1536 × 1024 PNG with genuine alpha and keeps the source's cream blob, heart, rays, and sparkles without baking the jar or UI into the image.
- Copy and content: greeting period changes with device time and appends the stored onboarding nickname. The subtitle and section title match the source. Date, medication names, dose details, times, and completion states remain live product data rather than copied mock content.

Focused region crops were not needed because the equal-size 1706 × 1844 comparison keeps the greeting, jar edges, doodles, section heading, card copy, badges, and navigation icons clearly readable.

### Findings

- No actionable P0/P1/P2 visual mismatch remains.
- P3: the live jar shows only the number of currently completed doses, while the source mock displays five stars for three medication cards. Preserving data truth and the existing falling-star interaction is preferable to copying that inconsistency.
- P3: longer user names scale the single-line greeting down to 70%; exceptionally long names may become visually smaller than the source headline but remain untruncated.

### Comparison history

1. Initial evidence: `/tmp/pillmate-home-redesign-v1.png`.
   - P2: the medications heading wrapped to two lines after adding the full year, and the three-card region extended beneath the floating tab bar.
   - Fix: gave the heading layout priority with one-line adaptive scaling, reduced date type to 12 points, and tightened cards from 90 to 82 points with 62-point time badges.
2. Post-fix evidence: `/tmp/pillmate-home-redesign-final.png` and `/tmp/pillmate-home-redesign-comparison.png`.
   - Result: the heading remains on one line and the three primary cards fit above the navigation at the reference density; additional live medicines continue below in the scrollable list.

### Implementation checklist

- [x] Time-aware Morning/Afternoon/Evening greeting
- [x] Stored onboarding nickname appended without stray punctuation for guests
- [x] Adaptive one-line greeting for longer names
- [x] Animated data-driven reward jar preserved
- [x] Transparent cream-and-lavender hero backdrop
- [x] Live full date including year
- [x] Functional dose completion buttons and celebration behavior preserved
- [x] Compact scrollable medication cards
- [x] Xcode simulator build, launch, screenshot, and visual comparison

## Apple Profile — Design QA

- Source visual truth: `/var/folders/z_/l_zb6spj6f3fxfgn8ncv71cm0000gn/T/codex-clipboard-16232348-9e5b-4210-a8a6-bde42de760ca.png`
- Implementation screenshot: `/tmp/pillmate-profile-apple-final.png`
- Side-by-side comparison: `/tmp/pillmate-profile-apple-comparison.png`
- Viewport: iPhone 17 Pro simulator, 402 × 874 points, light appearance
- Pixels and normalization: source 853 × 1844 px; implementation 1206 × 2622 px at 3×. The implementation was normalized to 853 × 1844 px and appended beside the source.
- State: Profile tab selected; preview name “Shuwen”; verified Apple-signed-in presentation; notifications enabled; reminder sound Default.

### Full-view comparison evidence

The final comparison preserves the source's complete structure: My Profile heading, centered initial avatar, account name, official Apple symbol with sign-in state, Edit profile action, flat Health/Reminders/Account sections with dividers, notification toggle, reminder-sound value, sign-out row, and selected Profile tab. The iOS status bar is preserved as platform-owned chrome.

### Required fidelity surfaces

- Fonts and typography: SF Rounded matches the friendly heavy headings and medium setting labels. Hierarchy, one-line row labels, subdued descriptions, and centered account copy remain readable without truncation.
- Spacing and layout rhythm: the final compact pass uses a 76-point avatar, 48-point rows, 12-point section gaps, and a 50-point sign-out row so the complete screen remains visible above the bottom navigation.
- Colors and visual tokens: pale lavender background, deep-plum primary text/icons, muted purple secondary text, lavender avatar gradient, saturated toggle, and selected Profile surface match the source.
- Image and icon fidelity: no raster illustration is required on this screen. Native SF Symbols provide the settings icons and Apple's official `apple.logo`; no Apple mark was redrawn or embedded.
- Copy and content: My Profile, Signed in with Apple, Edit profile, all section labels, setting titles/descriptions, Default, and Sign out match the supplied reference.

Focused region crops were not required because the normalized full-view comparison keeps the Apple status line, all setting copy, toggle, chevrons, sign-out action, and bottom navigation clearly readable.

### Identity and interaction verification

- `Signed in with Apple` appears only when the saved Apple user identifier exists; the simulator visual uses an explicit Debug-only Apple-profile state.
- Guest users receive `Using Pillmate as guest` instead of a fabricated login state.
- Edit profile opens a native sheet and persists the revised name/email.
- Notification changes are persisted and cause active reminder requests to be resynchronized or cleared.
- Reminder sound provides Default, Gentle, and None choices.
- Health information, Privacy & data, and About rows navigate to real in-app destinations.
- Sign out clears the Apple identifier and profile-complete state, returns to onboarding, and leaves local medication records intact.

### Comparison history

1. Initial evidence: `/tmp/pillmate-profile-apple-v1.png`.
   - P2: section and row spacing caused About and Sign out to remain below the bottom navigation at the initial scroll position.
   - Fix: reduced main top padding from 18 to 4 points, section gaps from 16 to 12 points, setting rows from 52 to 48 points, and the sign-out row from 54 to 50 points.
2. Post-fix evidence: `/tmp/pillmate-profile-apple-final.png` and `/tmp/pillmate-profile-apple-comparison.png`.
   - Result: all source sections and Sign out are visible in the initial viewport with no actionable P0/P1/P2 mismatch.

### Implementation checklist

- [x] Real Apple-identifier-driven status
- [x] Official Apple SF Symbol
- [x] Stored name and initial avatar
- [x] Functional Edit profile sheet
- [x] Guest-state fallback
- [x] Persistent notification toggle and reminder resync
- [x] Reminder sound menu
- [x] Navigable setting rows
- [x] Functional sign out without deleting local medicine history
- [x] Xcode simulator build, launch, screenshot, and visual comparison

## Guest Profile — Design QA

- Source visual truth: `/var/folders/z_/l_zb6spj6f3fxfgn8ncv71cm0000gn/T/codex-clipboard-4c4403c5-fed7-4efd-a1d1-0c460bf0a1cb.png`
- Implementation screenshot: `/tmp/pillmate-profile-guest-v2.png`
- Normalized implementation: `/tmp/pillmate-profile-guest-normalized.png`
- Side-by-side comparison: `/tmp/pillmate-profile-guest-comparison.png`
- Viewport: iPhone 17 Pro simulator, 402 × 874 points, light appearance
- Pixels and normalization: source 853 × 1843 px; implementation 1206 × 2622 px at 3×. The implementation was normalized to 853 × 1843 px and appended beside the source.
- State: guest Profile tab, notifications enabled, reminder sound Default, no Apple credential saved.

### Full-view comparison evidence

The equal-size side-by-side comparison preserves the reference hierarchy: My Profile heading, horizontal Guest identity block, official black Continue with Apple control, short account prompt, three outlined setting cards, guest reassurance, and selected Profile tab. The implementation retains the native iOS status bar and Dynamic Island; the source omits platform chrome, so its small vertical-density difference is expected.

### Required fidelity surfaces

- Fonts and typography: SF Rounded reproduces the friendly heavy heading, bold Guest identity, semibold row labels, and muted lavender support text. Labels remain untruncated at the tested viewport.
- Spacing and layout rhythm: 20-point page margins, 64-point avatar, 54-point Apple button, compact two-row cards, 14-point radii, and consistent section gaps keep all content visible above the tab bar.
- Colors and visual tokens: pale lavender background, deep-plum text/icons, lavender gradient avatar, thin lavender card outlines, translucent white card fills, and saturated purple toggle follow the source palette.
- Image quality and asset fidelity: this screen requires no custom raster illustration. Profile and setting marks use sharp native SF Symbols, while the Apple sign-in mark and label come from Apple's official `SignInWithAppleButton` component rather than a redrawn asset.
- Copy and content: Guest, Using Pillmate on this device, Continue with Apple, Sign in to create your account, all three section labels, settings copy, and the guest reassurance match the supplied reference.

Focused region crops were not needed because the normalized full-view comparison keeps the Apple mark, identity copy, card borders, row icons, toggle, chevrons, footer, and navigation clearly readable.

### Findings

- No actionable P0/P1/P2 mismatch remains.
- P3: the official Apple button's internal typography and padding vary slightly from the design mock; preserving the platform-owned component is intentional and required for compliance.
- P3: native status-bar chrome shifts the page content slightly downward compared with the chrome-free source mock.

### Identity and interaction verification

- Guest and Apple-signed-in profiles render as distinct states driven by the saved Apple user identifier.
- Apple authorization requests full name and email through the official system control.
- Cancellation remains on the guest Profile without an error.
- Non-cancellation failure states explicitly report the missing Xcode/App ID Sign in with Apple configuration instead of fabricating success.
- Successful authorization stores the Apple identifier and available profile values, then switches the current screen to the signed-in profile.
- Health information, Privacy & data, About, notifications, and reminder sound remain functional for guests and signed-in users.

### Comparison history

1. First intended-state capture: `/tmp/pillmate-profile-guest-v1.png` landed on a previously selected Health information detail and was rejected as invalid comparison evidence.
2. Corrected capture: the app was cleanly terminated and relaunched into the guest Profile root, producing `/tmp/pillmate-profile-guest-v2.png` and `/tmp/pillmate-profile-guest-comparison.png`.
   - Result: correct auth state, route, content, full-card visibility, and native platform chrome; no visual fix was required after the valid comparison.

### Implementation checklist

- [x] Separate guest identity header
- [x] Official Continue with Apple component
- [x] Honest cancellation and failure handling
- [x] Apple success switches to signed-in Profile
- [x] Functional guest health and care links
- [x] Persistent guest notification and sound controls
- [x] Functional privacy and About links
- [x] Guest reassurance copy
- [x] Xcode simulator build, launch, screenshot, and normalized visual comparison

## Low-stock Reminder — Design QA

- Source visual truth: `/var/folders/z_/l_zb6spj6f3fxfgn8ncv71cm0000gn/T/codex-clipboard-f5f3a1e2-e5bc-48b3-9107-9bae50b772db.png`
- Implementation screenshot: `/tmp/pillmate-add-medicine-low-stock-final.png`
- Combined comparison evidence: `/tmp/pillmate-low-stock-comparison.png`
- Viewport: iPhone 17 Pro simulator, 402 × 874 points, light appearance
- Pixels and normalization: source 1774 × 887 px; implementation 1206 × 2622 px at 3×. The source was normalized to 1206 × 602 px and vertically appended with the implementation so both artifacts could be inspected together without suggesting a false same-viewport comparison.
- State: Add medicine sheet, Supply section in view, low-stock reminder enabled, starting quantity 30 tablets, threshold 5 tablets.

### Comparison scope and full-view evidence

The source is a visual direction for the notification—not a mock of the Add Medicine form—so exact screen geometry is intentionally not compared. The combined evidence verifies that the new control inherits Pillmate's pale lavender canvas, translucent rounded surface, deep-plum copy, purple state color, and compact single-purpose hierarchy. The production notification itself is rendered by iOS using the Pillmate app icon on the left and a single body line.

### Required fidelity surfaces

- Fonts and typography: the form uses SF Rounded with the existing editor hierarchy; the notification body is intentionally one concise system-rendered line and does not include medicine strength or mg.
- Spacing and layout rhythm: the three Supply rows share consistent dividers, vertical padding, control widths, and a 21-point card radius. The expanded threshold row remains comfortably tappable and does not collide with the sheet toolbar.
- Colors and visual tokens: the reference's lavender, white, plum, and purple direction maps to existing `AppColors` tokens and the native purple Toggle state.
- Image quality and asset fidelity: the actual notification uses the app icon supplied to iOS rather than drawing a star inside the notification. The form requires no new raster imagery or placeholders.
- Copy and content: the form clearly explains Low stock reminder, the adjustable remaining-tablet threshold, and the one-time trigger. The produced message format is `Amlodipine is running low · 5 tablets left`, which follows the requested concise style and omits mg.

Focused crops were not needed because the combined evidence keeps the reference notification, all three Supply rows, threshold controls, explanatory footer, and surrounding editor context clearly readable.

### Findings

- No actionable P0/P1/P2 mismatch remains.
- P3 test gap: the real iOS banner was not captured because notification authorization is platform-owned; its content, app icon placement, sound, one-second local trigger, and foreground banner presentation are implemented through `UNUserNotificationCenter`.

### Comparison history

1. Initial editor capture: `/tmp/pillmate-add-medicine-low-stock-v1.png` showed the full form from the top, but the expanded threshold control was below the viewport and therefore invalid as final visual evidence.
2. Fix: added a Debug-only preview route that opens Add Medicine with Low stock reminder enabled and scrolls the Supply section into view; production scrolling and default-off behavior remain unchanged.
3. Post-fix evidence: `/tmp/pillmate-add-medicine-low-stock-final.png` and `/tmp/pillmate-low-stock-comparison.png` show the complete Supply configuration with no clipping or density issue.

### Implementation checklist

- [x] Persist low-stock enabled state per medicine
- [x] Persist user-selected remaining-tablet threshold
- [x] Clamp threshold between 1 and starting quantity
- [x] Trigger only after a newly completed dose reaches the threshold
- [x] Respect the global Notifications setting
- [x] Skip reminders for skipped or merely viewed doses
- [x] Use concise singular/plural notification copy without mg
- [x] Request notification authorization when low-stock reminders are enabled
- [x] Simulator build, launch, screenshot, and combined visual comparison

final result: passed
