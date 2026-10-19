# Product

## Register

product

## Users

Arabic-speaking learners and regular memorizers who want a simple, personal Quran companion. Confirmed by the user on 2026-10-18. No required account; local personal progress. Adjustable text size.

## Product Purpose

Access all 114 surahs, mark known surahs as memorized, learn new surahs, and save and name consecutive ayahs from larger surahs, and receive prayer reminders containing up to two nonoverlapping memorized surahs or opted-in passages to review for prayer. Design the UI/UX in FigCraft before Flutter implementation.

## Brand Personality

Calm, respectful, personal. Arabic by default with complete RTL navigation. Working name: سُوَر. User selected warm ivory, deep green and subtle gold ornament. Default Quran reading: Warsh from Nafi, explicitly selected by the user.

## Design Principles

1. Recall should be easy: move from a reminder to familiar surahs or passages in one tap.
2. Progress belongs to the user: memorized status is explicit and reversible; practice is self-assessed.
3. Readability comes first: generous Quran text, simple controls, restrained Islamic ornament.

## Accessibility & Inclusion

Adjustable text size, readable Arabic UI, full RTL, 48 px touch targets, labels alongside icons, status conveyed through text and shape as well as color. Plan screen-reader order, high contrast and reduced motion for Flutter.

## Scope

The approved editable FigCraft design remains the visual source. Flutter milestone 1 now implements offline reading, local memorization, Today suggestions and guided practice. Prayer milestone now provides offline calculated times, Casablanca by explicit user choice, manual Moroccan city/method/Asr settings, next-prayer countdown and Android opt-in reminders with known-surah suggestions. Calculated estimates are clearly labeled; reminders cover the next 30 calendar days and renew when the app opens. No recording, social feed or automated recitation grading in this phase.

## Audio milestone

Warsh/Husary audio is available for all114surahs, with publisher timings matching all6214sourceverseIDs. Learning supports1/3/5verse repetitions and hide-for-recall stopping. Explicit native per-surah downloads support offline listening, cancel/retry/size/delete and persist separately from personal progress. Browser streams with a clear native-download availability notice. Audio does not autoplay or continue in the background.

## Personal continuity milestone

Explicit source-ayah continuation and bookmarks are available in the reader, Home and Settings. A daily revision list uses selected memorized surahs and the prayer city's local calendar day, with reversible self-assessed completion. Local file backups have validation, preview, explicit replacement and startup rollback recovery. Restored reminders default off; audio and device permissions remain separate. Android has a launcher-confirmed next-prayer widget with city, absolute time, refresh age and tap-to-Prayer navigation.

## Named passages milestone — 0.6.0

Memory has separate Surahs and Passages sections. Save an exact consecutive range from one surah with an optional personal name, using approved presets, custom selection or an existing reader verse action. Preview and read the complete immutable Warsh source range. Saved, memorized and included in prayer suggestions are separate states; passage status never changes whole-surah progress. Renaming retains status; changing bounds requires confirmation and resets status. Exact duplicates open the existing record unchanged.

Home and prayer reminders select full surahs and explicitly eligible passages without overlapping ayahs. Old notification payloads remain supported; stale, changed or deleted passage references do not silently become another selection. Backup v2 includes passage data, supports v1 with explicit replacement disclosure, and uses compatible five-store recovery. This milestone does not add passage-specific audio clipping, folders or partial-surah completion percentages.

## Localization correction — 0.6.1

Arabic RTL uses Western digits0–9 throughout app presentation, including verse markers, while both Arabic digit input sets remain accepted. The bundled Warsh source remains immutable. Morocco follows permanentUTC+0 from September20,2026, with historical offsets preserved. Prayer display, daily boundaries, date-specific reminders and the Android widget share this correction even on devices with older time-zone data.
