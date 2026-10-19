# Morocco timezone correction

Verified 2026-10-19. The app retains `timezone` 0.10.1, whose embedded database is 2025b. Its Morocco predictions predate the current law. No saved city, Quran, passage, reading or revision data is migrated or cleared.

## Sources and exact boundary

[IANA release2026e Africa source](https://data.iana.org/time-zones/tzdb-2026e/africa), lines809–817 and877–897, defines Africa/Casablanca and Africa/El_Aaiun as +01 until September20,2026 at02:00 local, then permanent +00. The transition instant is **2026-09-20T01:00:00Z**:01:59:59 local+01 is followed by01:00:00 local+00. Historical transitions, including Ramadan2026 and summer2026, remain intact.

The [Moroccan ministry legal database](https://bdj.mmsp.gov.ma/Fr/Document/10664-D%C3%A9cret-n-2-26-530du-9-moharrem-1448-25-juin-2026.aspx?KeyPath=594/596/608/714/10664) identifies decree2-26-530 dated June25,2026, published June29 in Bulletin officiel7521. IANA links the [official Arabic bulletin](https://www.sgg.gov.ma/BO/AR/3111/2026/BO_7521_Ar.pdf). The technical boundary above is verified against IANA's actual zone definition, rather than inferred from the decree publication date.

## Implementation and trade-offs

`PrayerTimeZones` preserves each pinned location's transitions before the verified instant and replaces subsequent predictions with a permanent zero offset. It preserves IANA location names and every original historical zone. Other locations are unchanged. Initialization is shared by the calculator and notifications; lookups detect a replaced global database and reapply the overlay. This prevents another initializer from silently restoring obsolete predictions.

Updating to `timezone`0.11.2 would supply2026e, but the current notifications19.5 dependency requires timezone^0.10.0. Upgrading that dependency tree or rebuilding the entire database is broader than this correction. The [timezone changelog](https://pub.dev/packages/timezone/changelog) documents both the new data and intervening API changes. Dependencies remain pinned; no package-cache edits or runtime downloads are involved.

Android notifications19.5 reconstruct their stored wall-clock value through the device's `ZoneId` database. A stale Android database can therefore undo an app-only data correction. Date-specific alarms are transmitted as **UTC wall time with zoneUTC**, preserving their absolute instants during initial scheduling and reboot restoration. Corrected city-local dates still determine notification IDs and coverage. Existing app-owned jobs are refreshed on runtime startup; the rules version also participates in the scheduling fingerprint.

Widget snapshots retain UTC instants and the selected IANA city zone. The native widget clock applies the same cutoff when formatting either new or previously stored snapshots, so an old Android timezone database cannot keep displaying+01 after the change. Historical instants and other zones use normal system rules. Widget digits use Locale.US while Arabic labels remain Arabic. Widget/runtimes include the correction version in their fingerprints. Revision day boundaries already flow through the corrected prayer calculator.

## Verification and eventual removal

Focused tests cover both zones immediately before/at the boundary, preserved historical transitions, current/future offsets, unrelated zones, database reinitialization, midnight/next-Fajr behavior, revision rollover, widget timelines, and actual notification method-channel UTC arguments. The standalone native widget clock check exercises the cutoff, historical/Ramadan dates, future dates, legacy-zone formatting and Western numeric output on the JVM.

Remove the narrow overlay and corresponding native cutoff only after a compatible dependency update embeds IANA2026e or newer **and** stale Android databases remain handled: keep UTC alarm transport and use app-derived per-instant widget offsets or an equivalent verified native data path. Retain the historical/boundary regression tests. Update `rulesVersion` when authoritative rules change, so generated schedules/snapshots are refreshed. Do not replace the whole location with fixed UTC for all dates.
