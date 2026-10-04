# 📽️ Projekt: Maping / Własny Silnik Wizualny (Lazy Lighting Alternative)

> **Autor:** OBERON 🐾 & Szef  
> **Status:** Analiza zakończona, zasoby zabezpieczone  
> **Katalog projektu:** `~/projekty/maping`  
> **Zasoby:** `~/projekty/maping/extracted_assets/`

---

## 📌 1. Wstęp i Geneza

Celem projektu jest stworzenie **własnej, niezależnej aplikacji** do projekcji światła, efektów VJ oraz prostego mapowania projektora (projection mapping).

Bazą badawczą była analiza techniczna paczki *Lazy Lighting v4.0.2 (`com.audityapps.lazylighting`)*. Wyciągnięto kluczowe shadery i assety graficzne, eliminując konieczność opierania się na zewnętrznych systemach płatności (RevenueCat, Google Play Billing) czy chmurowych zależnościach.

---

## 📽️ 1.1 Profil Sprzętowy: Projektor HY320 Mini (Allegro / Smart TV LED)

Projektor Szefa: **HY320 Mini** ([Oferta Allegro](https://allegro.pl/oferta/projektor-rzutnik-przenosny-hy320-mini-smart-hd-led-android-wifi-tv-150-18675592408)).

### Charakterystyka sprzętowa w praktyce:
* **Typ urządzenia:** Kompaktowy, obrotowy rzutnik budżetowy typu Smart TV LED.
* **System operacyjny:** Android Smart TV (lekki interfejs kafelkowy).
* **Łączność:** Wi-Fi + pilot w zestawie.
* **Gniazda:** HDMI, USB, Audio Jack.
* **Ograniczenia wydajnościowe:** Posiada prosty, tani układ SoC (niewielka ilość pamięci RAM 1GB / flash). Instalowanie na nim ciężkich, zasobożernych aplikacji APK grozi zacinaniem lub zamykaniem procesów przez system Android.

### Dlaczego nasza architektura WWW (/display + /remote) jest dla niego idealna?
1. **Zero obciążenia:** Projektor nie przetwarza logiki aplikacji, nie obsługuje interfejsu ani suwaków.
2. **Czysty render:** Otwiera tylko stronę `/display` na pełnym ekranie wbudowanej przeglądarki.
3. **Moc obliczeniowa na telefonie:** Rysowanie masek, przeciąganie punktów po ekranie i cała obsługa odbywa się na szybkim smartfonie Szefa.



1. **Brak twardych pakerów/ochrony binarnej:**
   * Brak komercyjnych protectorów (*DexGuard, Bangcle, SecNeo, Promon SHIELD*).
   * Standardowe biblioteki C++ w `.so` (Google ML Kit, Barhopper, AndroidX Graphics).
2. **Obfuskacja:**
   * Bardzo lekki R8/ProGuard. Większość klas domenowych (`PlayViewModel`, `SubscriptionSource`, `ShaderEffect`) była jawna.
3. **Monetyzacja:**
   * Oparta w całości o **RevenueCat SDK** (`com.revenuecat.purchases`) i Google Play Billing.
   * Publiczny klucz dewelopera: `goog_zwKxQaDzCtmPWStrQsvvKabGSLn`.
   * Logika uprawnień opierała się na klasie `SubscriptionSource`, która dostarczała stan do Jetpack Compose.

---

## 📂 3. Zabezpieczone Zasoby (`extracted_assets/`)

Wszystkie kluczowe zasoby wizualne zostały wyodrębnione do katalogu:
`~/projekty/maping/extracted_assets/`

### A. Shadery OpenGL ES (`shaders/`) – 27 plików `.glsl`
* **Vertex shader:** `vertex_fullscreen.glsl` (podstawowy pełnoekranowy quad).
* **Fragment shadery efektów proceduralnych:**
  * `plasma_glow_frag.glsl`, `warp_plasma_frag.glsl`
  * `amoeba_smooth_frag.glsl`, `amoeba_walk_frag.glsl`
  * `blob_jello_frag.glsl`, `soft_blob_frag.glsl`
  * `flow_gradient_frag.glsl`, `color_explosion_frag.glsl`
  * `disco_texture_frag.glsl`, `interference_frag.glsl`
  * `kaleido2_frag.glsl` (kalejdoskop)
  * `levels_squares_frag.glsl`, `line_drop_frag.glsl`
  * `oil_swirl_frag.glsl`, `oscillo_ring_frag.glsl`
  * `rainbow_frag.glsl`, `simplex_frag.glsl`, `sine_warp_thing_frag.glsl`
  * `turbo_lence_frag.glsl`, `glow_border_frag.glsl`, `pie_shape_frag.glsl`

### B. Miniatury i Tekstury UI (`shader_images/`) – 28 plików `.png`
* Gotowe ikony podglądu dla każdego efektu shaderowego (do listy wyboru w interfejsie).

### C. Miniatury Pętli VJ (`vj_loop_thumbnails/`) – 25 plików `.jpg`
* Kafelki motywów (od `01.jpg` do `16.jpg`, `halloween_*.jpeg`, `window_*.jpeg`, `silhouette_*.jpeg`).

### D. Materiały Wideo (`raw_videos/`) – 5 plików `.mp4`
* Wbudowane pętle wideo (np. `loop2.mp4`, `welcome_clouds.mp4`, `welcome_santa.mp4`).

---

## 🎛️ 4. Parametry Sterujące Shaderami (`Uniforms`)

Każdy shader przyjmuje standardowy zestaw zmiennych, które można podpiąć pod suwaki w UI lub reakcję na dźwięk:

| Zmienna uniform | Typ | Przeznaczenie |
| :--- | :--- | :--- |
| `u_time` | `float` | Czas (animacja w czasie rzeczywistym) |
| `u_resolution` | `vec2` | Rozdzielczość ekranu / rzutu |
| `u_timeSpeed` | `float` | Mnożnik prędkości animacji |
| `u_zoom` | `float` | Skalowanie / przybliżenie kamery |
| `u_iterations` | `float` | Liczba iteracji algorytmu proceduralnego |
| `u_scale` | `float` | Skala wzoru |
| `u_frequency` | `float` | Częstotliwość fali / zakłóceń |
| `u_hueShift` | `float` | Przesunięcie barwy (0.0 - 1.0) |
| `u_colorBoost` | `float` | Nasycenie kolorów |
| `u_brightness` | `float` | Jasność globalna |
| `u_rotXSpeed`, `u_rotYSpeed` | `float` | Prędkość obrotu 3D |
| `u_rotXPhase`, `u_rotYPhase` | `float` | Kąt obrotu 3D |

---

## 🏗️ 5. Plan Realizacji Własnej Aplikacji (APK / Web)

Gdy znajdziemy czas, możemy zrealizować projekt w jednym z dwóch wariantów:

### Wariant 1: Natywna Aplikacja Android (APK)
* **Technologia:** Kotlin + Jetpack Compose + OpenGL ES 2.0 (`GLSurfaceView`) lub `RuntimeShader` (Android 13+).
* **Architektura:**
  * `ShaderRenderer`: kompiluje i renderuje wybrany plik `.glsl` na pełnym ekranie.
  * `MediaSource`: odtwarzanie lokalnych zdjęć i filmów (ExoPlayer/Media3) z nałożonymi efektami shaderów.
  * `YouTubePlayer`: wbudowany komponent WebView / IFrame Player API.
  * `KeystoneCorrection`: macierz 4-punktowej korekcji perspektywy (przeciąganie rogów palcem).
  * `AudioAnalyzer`: opcjonalna analiza FFT z mikrofonu modulująca `u_frequency` i `u_brightness`.
  * Brak jakichkolwiek blokad, subskrypcji czy bibliotek reklamowych.

---

## 🎬 6. Obsługa Własnych Multimediów (Zdjęcia, Wideo, YouTube)

Aplikacja będzie mogła rzucać na projektor / ścianę nie tylko generowane shadery, ale także:
1. **Własne zdjęcia (JPG, PNG, WebP):**
   * Wybór z galerii telefonu (`ActivityResultContracts.GetContent`).
   * Zdjęcie trafia jako tekstura (`sampler2D`) do shadera – można na nie nałożyć deformacje, fale, kolory lub korekcję perspektywy.
2. **Własne pliki wideo (MP4, MKV):**
   * Lokalne pliki odtwarzane w pętli za pomocą `Media3` / `ExoPlayer`.
   * Renderowanie klatek wideo bezpośrednio na powierzchnię OpenGL (`SurfaceTexture`).
3. **Wideo ze strumienia YouTube:**
   * Za pomocą oficjalnego YouTube IFrame API (w WebView) lub biblioteki ekstrakcji strumieni (np. *NewPipe Extractor*).
   * Możliwość odpalania dowolnego klipu w tle z zachowaniem geometrii rzutu!

---

## 💡 7. Kluczowe Funkcje Aplikacji (Architektura & Priorytety)

### 🥇 PRIORYTET KRYTYCZNY (MUST-HAVE 10000000%):
1. **✂️ Wielostrefowe Maskowanie Wielopunktowe (Multi-Surface / Multi-Window Mapping):**
   * **Absolutny fundament mappingu architektonicznego!**
   * **Obsługa DOWOLNEJ liczby powierzchni naraz:**
     * Np. 3 okna obok siebie, rama drzwi, 2 obrazy na ścianie czy regał z półkami.
     * Dodajesz przyciskiem: `[+ Dodaj nową strefę / okno]`.
   * **Niezależne 4-punktowe narożniki (Quad Warp) dla każdego okna:**
     * Każde okno ma własne 4 punkty, które rozciągasz palcem dokładnie na szyby/ramy (korekcja kąta i perspektywy każdego okna z osobna!).
   * **Dwa tryby pracy każdej strefy:**
     * **Strefa Projekcji (Surface):** Światło/efekt/wideo leci *tylko wewnątrz* tego okna.
     * **Maska Cienia (Blackout Cutout):** Projektor świeci na całą ścianę, ale na wybrane okno rzuca idealną czerń, żeby nie oślepiać pokoju w środku.
   * **Różne treści na różnych oknach:**
     * Na Oknie 1 leci padający śnieg (shader), na Oknie 2 animacja VJ, na Oknie 3 ciepły blask kominka!
2. **📱 Pilot przez Wi-Fi (Web Remote Controller w kieszeni):**
   * **Wygoda:** Urządzenie połączone z projektorem (telefon/tablet/TV box) stoi przy ścianie i rzuca obraz.
   * Wbudowany lekki serwer HTTP/WebSocket (Ktor / Node.js).
   * Wyciągasz swój telefon z kieszeni, wchodzisz na adres w przeglądarce i bez ruszania się z kanapy: zmieniasz sceny, regulujesz kolory, suwaki, przełączasz shadery, filmy i YouTube!


---

### 🥈 Funkcje Dodatkowe (Kolejne Etapy):
3. **🎵 Zaawansowana Reaktywność Audio (Beat & BPM Detection):**
   * Wykrywanie uderzeń basu (Kick Drum) – rozbłyski i pulsowanie w rytm muzyki.
4. **💡 Integracja z oświetleniem Smart Home (WLED / Philips Hue / Art-Net):**
   * Przesyłanie dominującego koloru z rzutnika na taśmy LED w pokoju (efekt Ambilight na całe pomieszczenie).
5. **💾 Presety i Playlisty:**
   * Zapisywanie profili ułożenia masek i efektów dla konkretnego pokoju/ściany.




## 🌟 8. GENIALNA ARCHITEKTURA: Web Display + Mobile Remote (No-App Needed!)

> **Koncepcja Szefa:** Projektor jest cały czas online i ma przeglądarkę (np. Android TV / Smart TV / Stick / RPi).  
> **Nie musimy kompilować żadnego APK!** Wszystko opiera się na technologiach Web (WebGL + WebSockets).

```
┌─────────────────────────────────┐           WebSocket           ┌─────────────────────────────────┐
│     PROJEKTOR (Ekran / TV)      │ <───────────────────────────> │     TELEFON (Pilot w dłoni)     │
│  Wchodzi na:                    │   (błyskawiczna zmiana scen,  │  Wchodzi na:                    │
│  http://serwer/display          │    kolorów, masek i filmów)   │  http://serwer/remote           │
│                                 │                               │                                 │
│  • Pełny ekran (F11)            │                               │  • Przyciski wyboru shaderów    │
│  • Render WebGL (nasze shadery) │                               │  • Suwaki barwy/prędkości/zoomu │
│  • Odtwarzacz wideo / YouTube   │                               │  • Edytor masek (rysowanie)     │
│  • Nakładanie wyciętych masek   │                               │  • Wklejanie linków YouTube     │
└─────────────────────────────────┘                               └─────────────────────────────────┘
                                                  ▲
                                                  │
                                  ┌───────────────────────────────┐
                                  │   LOKALNY SERWER (Node/Py)    │
                                  │   Termux / Perun / Minionek   │
                                  └───────────────────────────────┘
```

## 🔬 9. Dogłębna Analiza i Ulepszenia Projektu (Optymalizacja pod HY320 Mini)

Przeanalizowałem cały projekt, wyciągnięty kod shaderów oraz specyfikę układu scalonego w HY320 Mini (Allwinner H713 z GPU Mali-G31 MP2). Oto kluczowe wnioski i co możemy ulepszyć:

### 1. ⚡ Optymalizacja Shaderów pod budżetowe GPU Mali-G31
* **Problem:** Wyciągnięte shadery mają nagłówek `precision highp float;`. Układy Mali-G31 w tanich procesorach przy pełnej rozdzielczości 720p/1080p i `highp` mogą gubić klatki (zwłaszcza cięższe shadery jak `ios_visual_frag.glsl`, który ma 12 zagnieżdżonych pętli).
* **Ulepszenie:** 
  * Wprowadzenie automatycznego fallbacku `precision mediump float;` dla zmiennych kolorystycznych.
  * Renderowanie bufora shadera w natywnej rozdzielczości 720p (lub 540p ze skalowaniem w górę przez CSS/Canvas) – obraz na ścianie zachowuje idealną płynność 60 FPS, a obciążenie GPU spada o 60%.

### 2. 🎯 Architektura Maskowania (Homography / SVG Overlay)
* **Problem:** Liczenie przekształceń perspektywicznych w czystym CSS bywa ograniczone do płaszczyzny 2D, a liczenie macierzy perspektywy w shaderze może być skomplikowane przy wielu oknach.
* **Ulepszenie:**
  * Zastosowanie **podwójnej warstwy w przeglądarce**:
    * **Spód (Warstwa efektu):** Canvas WebGL renderujący animację/wideo.
    * **Wierzch (Maska SVG/Canvas 2D):** Czarna płachta z wyciętymi ścieżkami (`clip-path` lub `globalCompositeOperation = 'destination-out'`).
  * Pozwala to na nieskończoną liczbę okien/otworów z zerowym narzutem na procesor graficzny!

### 3. 🌐 Protokół Komunikacji Projektor <-> Telefon
* **Problem:** Klasyczny serwer WebSocket wymaga stabilnego połączenia w obie strony. Jeśli rzutnik na chwilę straci zasięg Wi-Fi, połączenie może się zerwać.
* **Ulepszenie:**
  * **Auto-Reconnect + LocalStorage Cache:** Projektor zapamiętuje ostatnie ułożenie masek i wybrany efekt w pamięci przeglądarki (`localStorage`). Po ponownym włączeniu rzutnika natychmiast odpala ostatnią scenę bez dotykania telefonu!

### 4. 🪟 Niezależne Treści na Różnych Oknach (Virtual Surfaces)
* Zamiast jednego shadera na cały rzutnik, podział na strefy:
  * **Okno Lewe:** padający śnieg.
  * **Okno Prawe:** ciepły blask świec / płomień kominka.
  * Osiągamy to przez zmapowanie współrzędnych UV shadera do poszczególnych wielokątów.

### 5. 📴 Tryb Standby / Sleep Screen (Oszczędzanie lampy LED)
* Przycisk na telefonie: `[Wygaś ekran (Blackout)]` – rzutnik rzuca 100% idealną czerń bez wyłączania urządzenia, np. gdy robisz przerwę lub wychodzisz z pokoju.


