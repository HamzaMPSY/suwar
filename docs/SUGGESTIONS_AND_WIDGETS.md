# Suggestion cycles and ayah widgets

Implemented November 22, 2026. Editable UI: [Suwar-cycle-widget.figcraft](../design/Suwar-cycle-widget.figcraft).

## Prayer suggestions

Today, «الاقتراح التالي», test reminders and scheduled prayer reminders share a device-local randomized cycle. All eligible memorized surahs and explicitly included memorized passages are suggested before another cycle begins. Al-Fatiha, including passages saved from it, is excluded without changing its memorized status.

Pairs never overlap in source ayahs. A cycle ends with one suggestion when an odd target remains, or when the remaining targets overlap. Newly eligible items join the remaining cycle; removed items are skipped. Opening the same upcoming prayer retains its pair. The history survives closing and reopening the app.

Future scheduled notifications reserve selections without advancing the current history. Visible previews and elapsed reminder slots advance it. The app preserves valid reservations when refreshing a schedule, cancels future reservations when reminders are disabled, and rebuilds them after manual selection. Reminder lead times retain the delivered pair until that prayer. Disabling suggested readings clears their reservations while retaining prayer alerts. After a partial scheduling failure, only reminders accepted by the platform retain reservations. The OS may delay or suppress a scheduled notification; the local cycle records its scheduled slot, not proof that a person saw it.

History is stored separately under `suwar.suggestions.v1`, excluded from portable progress backups. Existing suggestion history from before this feature cannot be reconstructed; the first cycle starts after this update.

## آية تُطمئنك

Open **Settings → آية تُطمئنك**. Choose all themes, reassurance, Jannah or Allah’s power. One complete ayah rotates per local calendar day; «آية أخرى» advances it explicitly. Selection is independent of memorization and works offline. Tap the widget or «قراءة الآية في سياقها» to open the exact source ayah in the existing reader. A pending tap waits for onboarding to finish.

The initial catalog contains 12 ayahs. Compact widgets use seven shorter entries, with at least one in every theme. The in-app iPhone preview represents the compact selection; larger widgets use the full catalog and can show a different ayah on the same day.

### Android

Add **سُوَر · آية تُطمئنك** from the device widget picker. The in-app pin request targets the home screen. Lock-screen placement depends on the OS and manufacturer; Android does not offer a universal app-controlled placement flow. See the [official Android lock-screen widget FAQ](https://android-developers.googleblog.com/2025/03/widgets-on-lock-screen-faq.html).

The resizable widget renders the bundled Warsh font and exposes the full ayah to accessibility. If its space cannot fit a complete ayah at the supported size, it asks the user to enlarge the widget. Its next action updates the shared widget selection. Android controls background update timing; rotation can occur after midnight rather than exactly at midnight.

### iPhone

On iOS 16+, customize the lock screen and add Suwar’s rectangular ayah widget. A medium home-screen widget is also included. iPhone controls the lock-screen tint and placement. Theme changes and the in-app next action request a WidgetKit timeline refresh; refresh delivery remains under OS control. See Apple’s [widget-extension documentation](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension).

Runner and AyahWidget share preferences through `group.com.suwar.suwar`. Enable this App Group for **both targets and their provisioning profiles** before a signed device build; see [release setup](RELEASE.md#build-the-iphone-app-and-ayah-extension). This work compiles for the simulator; signing, physical-device placement and background refresh still need device validation.

## Quran provenance

The catalog stores editorial references and theme labels in `assets/quran/remembrance-catalog.json`. Flutter and Android resolve each reference from the existing immutable `warsh-data.json`. The extension bundles an exact generated subset in `ios/AyahWidget/verses.json`; an automated test checks every entry against that source. After editing catalog references, regenerate this file with `python3 tool/generate_remembrance_subset.py`.

Source SHA256: `f05d0dc652fd46b38563cacb13242f76f80db4cc64d25873da0bce157253872f`. The font is the bundled `warsh.10.ttf`. The verified trailing verse-number marker is separated for display; the words and diacritics remain unchanged. References use Western digits and Warsh source numbering: the reassurance ayah is **13:29**, and the Jannah peace ayah is **36:57**. Context labels are editorial descriptions, not tafsir or generated Quran text.

## Visual references

[Actual Flutter settings screen](screenshots/ayah-widget.png) · [Android design preview](../design/previews/ayah-widget-android.png) · [iPhone design preview](../design/previews/ayah-widget-iphone.png) · [Cycle ending](../design/previews/suggestion-cycle-end.png)

## Verification

- 149 Flutter tests passed, including cycle persistence, odd/overlapping pools, Fatiha exclusion, future reservation reuse/cancellation, reminder lead-time continuity, source equality, daily rotation, exact-ayah navigation after onboarding, and narrow/double-scale layouts.
- Static analysis passed. Android debug APK and unsigned iOS simulator app/embedded widget builds passed.
- Actual Flutter screen and FigCraft previews inspected. All seven compact ayahs were measured with the bundled Warsh font at 17 pt / 150 pt width: each used 30 pt text height, leaving room for its reference.
- Device signing, OS widget placement, real notification delivery, lock-screen accessibility and background refresh are not established by these checks.
