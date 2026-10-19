# سُوَر · Design system

## Scene and direction

A person opens the app in daylight at home, checks the next prayer and quietly reviews familiar surahs. Warm ivory reduces glare and supports long reading. The user explicitly chose deep green and subtle gold ornament. Restrained product surfaces with a committed green prayer feature and welcome screen.

## Colors

Native FigCraft sRGB values, with equivalent OKLCH tokens to be recorded in the token export:
- Canvas ivory: #F7F4EA
- Elevated paper: #FFFCF5
- Deep green: #173F35
- Active green: #245C49
- Ink: #203C34
- Secondary ink: #66756B
- Gold ornament: #AC884B (decoration, never small body text)
- Dark gold text: #82632E
- Hairline: #DDDCCD
- Sage fill: #E8EEE5
- Caution: #8A512B

## Typography

Amiri for app name, display headings and surah titles. Noto Sans Arabic for controls, metadata, navigation and body copy. Quran text must use a verified Warsh-compatible Quran font and licensed authoritative Warsh text; do not substitute Hafs data. The review prototype may show a clearly identified text-source placeholder until that asset is verified. UI labels remain readable rather than ornate.

Display: 36/58. Screen heading: 30/48. Surah name: 26/42. Body: 16/28. Label: 14/24. Caption: 12/22. Quran default: 28 with generous line height and user size control. Do not add letter spacing to Arabic.

## Layout

390 × 844 mobile frames, 24 px horizontal margins, 8 px spacing foundation with 12/16/24/32 rhythm. Safe areas: 44 px top and 34 px bottom. Four-tab RTL navigation: اليوم, القرآن, حفظي, الصلاة from right to left. Settings accessible from the home header.

## Components

Primary button: green, 56 px height, 16 px radius. Secondary action: outlined or text with a 48 px target. Surah row: ornament index at right, name and verse count, explicit memorization state. Prayer feature: deep green surface with restrained geometric motif; suggestions on paper below. Dividers rather than boxes for long lists. Bottom navigation uses icons plus Arabic labels.

## Ornament

Eight-point rosettes, thin geometric lines and a simple mihrab arch. Ornaments are vector layers and stay away from Quran text. Gold used sparingly. No decorative motion.

## Motion and behavior

150–220 ms fade/slide for navigation, selection and feedback. Honor reduced motion. Swipe direction mirrors RTL; playback and numeric time keep logical order. All main actions must be prototype-linked in FigCraft.

## Numerals — user preference, 2026-10-19

Display Western digits (0–9) throughout the Arabic RTL interface, including counts, dates, times, range fields and ayah-number markers. Continue accepting Arabic and Eastern Arabic digits in search and range input. Scripture words, diacritics, source numbering and Warsh font remain unchanged; ayah marker digits use the UI font at the presentation boundary. This explicit preference supersedes Eastern-digit examples in older FigCraft reference screens.
