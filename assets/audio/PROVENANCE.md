# Husary Warsh audio catalog v1

Publisher: MP3Quran. Reciter: Mahmoud Khalil Al-Hussary / محمود خليل الحصري. Narration: Warsh an Nafi / ورش عن نافع. Official catalog reciter118, moshaf/read120, narration2. This is not moshaf118 (Hafs), and the URL path is `/r3/`, not `/r1/`.

- Official reciter catalog: https://mp3quran.net/api/v3/reciters?language=eng&reciter=118
- Official timing catalog: https://mp3quran.net/api/v3/ayat_timing/reads
- Per-surah timing: https://mp3quran.net/api/v3/ayat_timing?surah=1&read=120 (replace surah1 with1–114)
- Recording pattern: https://cdn.mp3quran.net/audio/mahmoud-husary/r3/001.mp3 (three-digit surah)
- Publisher permission statement: https://www.mp3quran.net/ar/privacy
- Publisher English statement: https://www.mp3quran.net/privacy-en.html
- Official API documentation: https://www.mp3quran.net/eng/api

The publisher permits visitors and developers to use its materials and links. This is the provider's permission statement, not an invented Creative Commons license or a separate claim of ownership. Keep reciter/narration/provider attribution visible. Audio streams and explicit user-requested downloads come from the publisher's HTTPS endpoint; the app does not bundle the audio recordings.

`warsh-husary-v1.json` pins the publisher's verse timing metadata, fetched2026-10-18. Its `retrievedUtc` records the actual retrieval. SHA256: `fe5f74d113792866962cde295dbaaf2882380b4ade0af8c8b9fd9d15f996db32`.

The catalog contains114 recordings and6214 timing intervals. Every chapter's positive ayah sequence exactly matches `assets/quran/warsh-data.json` from the existing KFGQPC Warsh source. Verified consecutive IDs, integer milliseconds, nonnegative starts, positive duration and no interval overlap. Distinctive counts: Al-Baqarah285, Al-Fajr32, Quraysh5. Example boundaries:1:1=13240–18720ms;2:1=7580–26220ms.

Only `ayah`, `start_time`, `end_time` and the identified recording URL are retained. Provider polygon/page metadata is deliberately excluded because the shared page artwork is not our Warsh display source. Unnumbered introduction/istiadhah/basmalah audio before the first segment is not a text ayah; whole-surah playback retains it, verse playback starts at the provided bound.

HTTP samples001/112 returned206 Partial Content, `audio/mpeg`, MP3 ID3 headers, byte-range support and `Access-Control-Allow-Origin: *` on2026-10-18. This confirms sample endpoint delivery, not a complete spoken audit. All6214 spoken boundaries have not been listened through. Physical-device boundary spot checks remain part of integration verification. Timing metadata remains subject to publisher accuracy; no offsets or silent corrections are guessed.

EveryAyah's Ibrahim Warsh directory was considered and rejected for direct verse mapping:6236 numbered files have Hafs-style counts, including Al-Baqarah286, Al-Fajr30 and Quraysh4. A Warsh recording label alone does not establish compatible verse segmentation.

Runtime catalog loading rejects substitutions, missing/duplicate chapters, count/sequence mismatches and malformed or overlapping intervals. The pinned catalog and recordings must be updated together after source revalidation; no live provider response replaces trusted metadata silently.
