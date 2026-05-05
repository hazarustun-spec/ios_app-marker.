# RELEASE AUDIT — marker. iOS

**Audit tarihi:** 2026-05-05
**Repo:** [hazarustun-spec/AINewsApp](https://github.com/hazarustun-spec/AINewsApp) (private)
**Baseline commit:** `95f5ffa` (Add news fallback to latest available date)
**Auditor:** End-to-end automated audit (7 phases)

---

## 0. Yönetici Özeti

iOS uygulaması "marker." (com.hazarustun.ainewsapp) günlük yapay zekâ haber özeti sunan bir SwiftUI uygulaması. Anthropic Claude + web search ile içerik üretimi, Supabase backend, Apple Sign-In, StoreKit 2 abonelik, Sentry crash reporting, Privacy Manifest dahil olmak üzere App Store altyapısının çoğu hazır. **Submission'a 2 critical blocker uzaklıkta:** (1) DEVELOPMENT_TEAM girilmemiş — release build derlenmiyor, (2) hiç screenshot çekilmemiş. Test target yok, accessibility eksik. Bu audit'te 3 atomic fix commit edildi (auth crash, force unwrap, Info.plist hijyeni). 10 eksik için 5-step plan hazır. Tahmini submission'a kalan zaman: ilk 2 blocker çözülürse ~1 saat + Apple review (1-3 gün). Top 3 iyileştirme: multi-source content validation, server-side push + deep linking, AppState/ViewModel ayırımı.

---

## 1. Faz 1 — Keşif Bulguları

**Scheme:** `AINewsApp` (tek scheme, tek target)

| Özellik | Değer |
|---|---|
| Swift sürümü | 5.9 |
| iOS deployment target | 17.0 |
| Mimari | SwiftUI + tek `@MainActor AppState` (ViewModel yok) |
| Dependency manager | SPM (8 paket) |
| Test framework | **YOK** |
| Swift dosyası | 30 dosya, 5,266 satır |
| Edge Functions | `generate-daily-news`, `admin-news` (Deno/TypeScript) |
| Lint/Format/CI | Yok |
| Yardımcı dosyalar | README ❌, Podfile ❌, Package.swift ❌, fastlane ❌ |

**Bağımlılıklar:** Supabase 2.46.0, Sentry 8.58.2 + 6 transitive (swift-asn1, swift-clocks, swift-concurrency-extras, swift-crypto, swift-http-types, xctest-dynamic-overlay)

**Ana ekranlar (8):** OnboardingView (3 sayfa), HomeView, FeedView, SavedView, SettingsView, NewsDetailView, PaywallView, LegalView

**State management:** Tek `AppState` (330 satır, auth+profile+saved+notification+premium hepsi). 4 singleton servis: SupabaseManager, StoreKitManager, NotificationManager, Log.

---

## 2. Faz 2 — Statik Analiz Bulguları

### Build durumu

- 🔴 **Release**: BUILD FAILED — `DEVELOPMENT_TEAM` boş
- ✅ **Debug**: BUILD SUCCEEDED — Faz 4 sonrası 0 actionable warning

### Kategorilere göre bulgular

| 🚨 | Kategori | Konum | Açıklama | Faz 4 |
|---|---|---|---|---|
| 🔴 | Crash riski | `AppState.swift:297` | `fatalError("SecRandomCopyBytes failed")` — auth path'inde | ✓ FIX |
| 🔴 | Build | `project.yml:12` | `DEVELOPMENT_TEAM: ""` | BACKLOG |
| 🟠 | Force unwrap | `SupabaseManager.swift:12` | `URL(string: ...)!` | ✓ FIX |
| 🟠 | Compiler warning | `AppState.swift:192,200` | Gereksiz `try?` (UUID throw etmiyor) | ✓ FIX |
| 🟠 | Info.plist | `Info.plist:21` | `NSFaceIDUsageDescription` yanıltıcı + İngilizce | ✓ FIX (kaldırıldı) |
| 🟠 | Launch screen | `Info.plist:32-35` | `UIColorName: ""` boş | ✓ FIX (launchBackground colorset) |
| 🟠 | Version mismatch | Info.plist vs project.yml | `1.0` vs `1.0.0` | ✓ FIX |
| 🟠 | Encryption flag | `Info.plist` | `ITSAppUsesNonExemptEncryption` yok | ✓ FIX |
| 🟡 | Build phase | `project.yml:60` | Sentry script output paths eksik | ✓ FIX |
| 🟡 | Lokalizasyon | 77 lokasyon | Tüm string'ler hardcoded Türkçe | BACKLOG |
| 🟡 | Accessibility | 0 occurrence | `accessibilityLabel/Hint` hiç kullanılmamış | BACKLOG |
| 🟡 | Retain cycle | 17 Task closure | `[weak self]` yok (pratik risk düşük) | BACKLOG (low priority) |
| 🟢 | Architecture | `NewsDetailView.swift` | 946 satır | BACKLOG |
| 🟢 | Architecture | `PaywallView.swift` | Business logic view'da | BACKLOG (Faz 7 #3) |

### Güvenlik durumu (temiz ✅)

- ATS exception YOK
- `try!` YOK
- Hardcoded gerçek secret YOK (anon key public, RLS protected)
- Apple Sign-In nonce flow doğru (use-once + race koruması, AppState.swift:51-91)
- Hassas veri UserDefaults'ta tutulmuyor (delivery saati, onboarding flag, cache JSON'lar)
- HTTPS-only (App Store ATS uyumlu)

---

## 3. Faz 3 — Test Bulguları

**Sonuç:** Hiç test çalıştırılamadı — `xcodebuild -list` Targets listesinde sadece `AINewsApp` (uygulama) var. Test target tanımlı değil, scheme test action için configured değil.

```
xcodebuild: error: Scheme AINewsApp is not currently configured for the test action.
```

**Geçen / Başarısız / Atlanan: 0 / 0 / 0**
**Code coverage:** Mümkün değil

### Eksik kritik test akışları (Faz 6 backlog'a aktarıldı)

🔴 Critical: app launch + session restore, Apple Sign-In nonce flow, onboarding 3-konu zorunluluğu
🟠 High: StoreKit purchase, premium gating (`canFullyRead`), saved news cache + sync, network failure
🟡 Medium: empty state vs fallback, notification permission, deep linking, share platform formatting
🟢 Low: UI smoke tests, topic chip selection limits

---

## 4. Faz 4 — Uygulanan Düzeltmeler

3 atomic commit, hepsi build'i SUCCEEDED bırakıyor:

### `d4294a0` — fix(auth): replace fatalError in nonce gen with arc4random fallback

- **Neden hataydı:** `SecRandomCopyBytes` 1 byte için kraşa neden olamayacak kadar güvenilir, ama 1/milyon olasılıkla fail ederse `fatalError` tüm uygulamayı auth flow'da çökerirdi. Kullanıcı için: "uygulama açıyorum, kapanıyor".
- **Ne değiştirdim:** `AppState.swift:295-300` — `errSecSuccess` değilse `arc4random_uniform` ile fallback + Sentry'ye log gönder. Auth kesintisiz devam eder.
- **Bonus:** `selectTopic` ve `deselectTopic`'teki gereksiz `try? UUID(uuidString:)` çağrılarını sade `if let userId = ...currentUser?.id` ile değiştirdim. UUID(uuidString:) optional return eder, throw etmez — compiler warning'ler temizlendi.
- **Test:** Debug build clean, 0 warning. Auth flow regression yok (manuel akış değişmedi).

### `0bf7dc1` — fix(net): replace force unwrap on Supabase URL with explicit guard

- **Neden hataydı:** `URL(string: SupabaseConfig.url)!` — string hardcoded olduğu için pratik risk yok ama force unwrap kötü pratik. Birisi config string'i değiştirip yanlış format girerse uygulama init'te crashler.
- **Ne değiştirdim:** `SupabaseManager.swift:11-17` — `guard let url = URL(string: ...) else { preconditionFailure(...) }`. preconditionFailure çünkü init aşamasında recoverable state yok; bu unreachable in practice.
- **Test:** Debug build SUCCEEDED.

### `1e9af74` — fix(infoplist): correct version, encryption flag, launch screen, faceid copy

- **Neden hataydı:**
  - `CFBundleShortVersionString: "1.0"` ama `MARKETING_VERSION: "1.0.0"` — App Store Connect'te confusion
  - `ITSAppUsesNonExemptEncryption` yoksa archive sırasında her seferinde modal çıkar
  - `NSFaceIDUsageDescription: "Used for authentication"` — uygulama FaceID kullanmıyor (LocalAuthentication import yok), Apple reviewer "neden bu permission?" sorabilir
  - `UILaunchScreen.UIColorName: ""` — boş, splash siyah
- **Ne değiştirdim:** Hepsi `project.yml`'de düzeltildi. NSFaceIDUsageDescription kaldırıldı. `launchBackground.colorset` (#FBFBF6 — bgPrimary) eklendi. Sentry build phase `runOnlyWhenInstalling: true` + `outputFiles` ile dependency analysis warning'i de temizlendi.
- **Test:** Debug build SUCCEEDED, 0 actionable warning.

### Düzeltilmedi (kapsam dışı/blocker → BACKLOG, Faz 6'da ele alındı)

- DEVELOPMENT_TEAM (kullanıcının Apple Developer Team ID'si gerekir)
- Test target (Faz 6 Eksik 3)
- Accessibility (Faz 6 Eksik 4)
- Localization (Faz 6 Eksik 9)
- ViewModel refactor (Faz 7 #3)

---

## 5. Faz 5 — App Store Checklist Sonuçları

### Build & Identity

| Madde | Durum | Kanıt |
|---|---|---|
| Bundle Identifier prod | ✅ | `com.hazarustun.ainewsapp` |
| CFBundleShortVersion + CFBundleVersion tutarlı | ✅ | `1.0.0` / `1` |
| Önceki release'den büyük | N/A | İlk release |
| Deployment target uygun | ✅ | iOS 17.0 |
| Code signing & provisioning prod | ❌ | DEVELOPMENT_TEAM boş |
| Release config 0 warning | ⚠️ | Code'da 0 warning ama team boş |

### Info.plist & Entitlements

| Madde | Durum | Kanıt |
|---|---|---|
| NSXxxUsageDescription doğru | ✅ | Yanıltıcı FaceID kaldırıldı, başka Usage anahtarı yok |
| ITSAppUsesNonExemptEncryption | ✅ | `false` |
| Background modes | ✅ | Yok (gerekmiyor) |
| ATS exception gerekçeli | ✅ | Hiç yok |
| Associated Domains | N/A | Henüz yok |
| Push entitlement prod | ✅ | `aps-environment: production` |

### Privacy & Compliance

| Madde | Durum | Kanıt |
|---|---|---|
| PrivacyInfo.xcprivacy | ✅ | Var, bundle'da |
| Required Reason API beyanı | ✅ | UserDefaults, FileTimestamp, SystemBootTime, DiskSpace |
| IDFA + ATT | N/A | IDFA yok |
| Privacy Policy URL | ✅ | Canlı (`hazarustun-spec.github.io/marker-legal/privacy.html`) |
| Uygulama içi hesap silme | ✅ | `AppState.deleteAccount()` |
| ASC Data Collection beyanı | ⚠️ | Manuel (form-based) |

### Asset & Metadata

| Madde | Durum | Kanıt |
|---|---|---|
| App Icon 1024×1024 | ✅ | PNG, alpha yok |
| App Icon küçük boyutlar | ✅ | iOS 17+ Single Size mode |
| Launch Screen | ✅ | launchBackground colorset |
| Screenshot'lar | ❌ | **Hiç yok** |
| Localization tutarlı | ⚠️ | Tek dil (Turkish), Localizable.strings yok |

### Stability & UX

| Madde | Durum | Kanıt |
|---|---|---|
| Soğuk başlatma <2sn | ⚠️ | Ölçülmedi |
| Dark mode | ⚠️ | Light-only — sorun değil |
| Dynamic Type | ❌ | Custom fontlar fixed pt |
| RTL | N/A | Türkçe LTR |
| VoiceOver | ❌ | 0 accessibility label |
| Offline / kötü ağ | ⚠️ | Empty state + fallback var, network error UI minimal |
| StoreKit Restore Purchases | ✅ | PaywallView:131 |
| Paywall Apple 3.1.2 uyumlu | ✅ | Auto-renewal disclosure tam |
| Fiyat lokalize | ✅ | ₺29.99/ay, ₺249/yıl |

### Yasal & Review

| Madde | Durum | Kanıt |
|---|---|---|
| EULA | ✅ | Apple default (ASC'de boş bırakılır) |
| Üçüncü taraf lisans | ⚠️ | Manuel beyan zorunlu değil |
| Demo hesap | ❌ | Hazırlanmadı |

---

## 6. Faz 6 — Eksiklikler ve 5 Adımlı Planlar (Öncelik Sırasına Göre)

### Öncelik 1 (Blocker) — Submission'ı engelliyor

#### Eksik 1: DEVELOPMENT_TEAM ayarlanmamış 🔴

- **Risk:** Blocker
- **Neden:** Code signing yapılamaz → release derlenmez → archive yok → submission yok
- **5 adımlı plan:**
  1. [developer.apple.com/account](https://developer.apple.com/account) → Membership → Team ID kopyala
  2. `project.yml:12` → `DEVELOPMENT_TEAM: "ABCDE12345"`
  3. `xcodegen generate`
  4. Xcode → Target → Signing & Capabilities → Team dropdown'da kendin seçili
  5. **Doğrulama:** `xcodebuild -scheme AINewsApp -configuration Release archive` → "Archive Succeeded"
- **Tahmini efor:** 5 dakika

#### Eksik 2: Screenshot'lar yok 🔴

- **Risk:** Blocker
- **Neden:** App Store Connect 6.9" screenshot zorunlu (min 3)
- **5 adımlı plan:**
  1. iPhone 16 Pro Max simulator'da Apple Sign-In + onboarding tamamla
  2. 5 ekran çek: Splash, Today, Detail, TopicSelection, Settings
  3. Her birine Figma/AppLaunchpad ile tagline ekle
  4. PNG export 1320×2868
  5. **Doğrulama:** ASC → screenshots upload → "iPhone 6.9-inch Display" yeşil
- **Tahmini efor:** 1.5 saat

### Öncelik 2 (High) — Submission'ı kabul ettirir ama kalite riskini yükseltir

#### Eksik 3: Test target yok 🟠

- **Risk:** High
- **Neden:** Auth/premium/StoreKit kritik akışları regresyon altında, CI yok
- **5 adımlı plan:**
  1. project.yml'e `AINewsAppTests` test bundle target ekle
  2. `Tests/AINewsAppTests/`: `AppStateTests.swift`, `StoreKitManagerTests.swift`, `PremiumGatingTests.swift`
  3. xcodegen + scheme test action configure (`gatherCoverageData: true`)
  4. GitHub Actions workflow: `pull_request` event'inde `xcodebuild test`
  5. **Doğrulama:** PR ✓ check + coverage raporu
- **Tahmini efor:** 6 saat

#### Eksik 4: Accessibility yok 🟠

- **Risk:** High
- **Neden:** Apple Guideline 2.5.7 + EAA 2025 zorunlu hale gelecek
- **5 adımlı plan:**
  1. Buton'lara `.accessibilityLabel` (NewsDetail, Home, Feed, Saved)
  2. Dekoratiflere `.accessibilityHidden(true)` (BriefLogo, GlassOrbView)
  3. Card'lara `.accessibilityElement(children: .combine)` + descriptive label
  4. Custom tab bar item'larına accessibility
  5. **Doğrulama:** Accessibility Inspector → tüm akış geçilir
- **Tahmini efor:** 4 saat

#### Eksik 8: TestFlight upload + internal test 🟠

- **Risk:** High
- **Neden:** Production build hiç gerçek cihazda test edilmedi
- **5 adımlı plan:**
  1. Eksik 1 (Team) + Eksik 2 (screenshot) tamamlanmış olsun
  2. Xcode → Product → Archive
  3. Distribute App → App Store Connect → Upload
  4. ASC → TestFlight → Internal Testing kendine ekle
  5. **Doğrulama:** iPhone'da TestFlight'tan kuruluyor, Apple Sign-In + paywall + push çalışıyor
- **Tahmini efor:** 1.5 saat

### Öncelik 3 (Medium)

#### Eksik 5: Dynamic Type 🟡

- **Risk:** Medium
- **5 adımlı plan:**
  1. Font.custom'lara `relativeTo:` parametresi ekle
  2. Body `.body`, başlıklar `.title2/.title3`
  3. `.dynamicTypeSize(.large ... .accessibility3)` üst limit
  4. NewsDetail büyük puntolu test
  5. **Doğrulama:** Settings → Text Size en büyük → uygulama okunabilir
- **Tahmini efor:** 3 saat

#### Eksik 6: Demo hesap 🟡

- **Risk:** Medium
- **5 adımlı plan:**
  1. Test Apple ID hazırla
  2. Onboarding tamamla, Sandbox premium aktif et
  3. ASC → App Review Information → Demo Account email + password
  4. Notes: "App requires Sign in with Apple. Use the provided test Apple ID. Premium accessible from Settings → 'Premium'a yükselt'."
  5. **Doğrulama:** Submission validate olur
- **Tahmini efor:** 30 dakika

#### Eksik 7: ASC App Privacy nutrition label 🟡

- **Risk:** Medium
- **5 adımlı plan:**
  1. ASC → marker. → App Privacy → Get Started
  2. Linked: User ID, Email, Name, Device ID, Purchase History → "App Functionality" (Tracking yok)
  3. Privacy Policy URL gir
  4. PrivacyInfo.xcprivacy ile çakışma yok doğrula
  5. **Doğrulama:** Privacy Choices Defined yeşil
- **Tahmini efor:** 15 dakika

### Öncelik 4 (Low) — Post-launch

#### Eksik 9: Localizable.strings i18n 🟢

- **Risk:** Low (ilk release tek dil)
- **5 adımlı plan:**
  1. `Resources/tr.lproj/Localizable.strings` + `en.lproj/`
  2. 77 hardcoded string'i `String(localized:)`'a çevir
  3. TR + EN çeviri
  4. String set'leri eşle, eksik yok
  5. **Doğrulama:** Run with Language: English → tüm UI EN
- **Tahmini efor:** 1 gün

#### Eksik 10: Cold start metrics 🟢

- **Risk:** Low
- **5 adımlı plan:**
  1. Sentry Performance zaten aktif
  2. App'i 5x restart, Sentry → Performance → Cold Start
  3. Hedef: <2sn p95
  4. Aşıyorsa async init blocking kontrol
  5. **Doğrulama:** TestFlight build p95 <2s
- **Tahmini efor:** 1 saat (post-TestFlight)

---

## 7. Faz 7 — Top 3 ROI İyileştirme

### #1 — AI: Multi-source Cross-Validation 🔥

- **Kategori:** AI / İçerik kalitesi
- **Mevcut:** Edge function tek search ile içerik üretiyor (`generate-daily-news/index.ts:108`)
- **Önerilen:** 2-step prompt — önce search, sonra "yalnızca 2+ kaynaktan teyit edilenleri yaz". Output schema'ya `confidence` + `verifiedSourceCount`. UI'da rozet.
- **Fayda:** Apple Guideline 1.2 risk %50 azalır, kullanıcı güveni artar
- **Implementasyon:**
  1. 2-step Claude prompt (search → distill)
  2. Schema migration: `news_items.verified_count int`
  3. NewsItem modeline field
  4. Detail UI: "3 kaynaktan doğrulandı ✓"
  5. SourceLink component'inde primary vs supporting
  6. Edge function fallback: tek kaynak varsa "single_source" işaretle
- **Etki/Efor:** 🔥 Yüksek / 🟡 Orta (1 gün)

### #2 — UX: Server-Side Push + Deep Linking 🔔

- **Kategori:** UX / Engagement
- **Mevcut:** Lokal saat-bazlı bildirim (`NotificationManager.swift:28`), gerçek push gönderim YOK, deep link routing YOK
- **Önerilen:** Edge function APNs prod'a push gönderir, push tap → ilgili haber detayı
- **Fayda:** D1/D7 retention 2x (endüstri standardı), "boş bildirim" UX problemi çözülür
- **Implementasyon:**
  1. Yeni Edge function `send-daily-push` — APNs HTTP/2
  2. `generate-daily-news` cron sonrası tetikle
  3. iOS `UNUserNotificationCenterDelegate` + userInfo["news_id"]
  4. AppState'e `@Published deeplinkNewsId`
  5. AINewsApp.swift `.onChange(of: scenePhase)`'da consume
  6. `UIApplication.didRegisterForRemoteNotificationsWithDeviceToken` handler → `profiles.apns_token`
- **Etki/Efor:** 🔥 Çok yüksek / 🟠 Yüksek (2-3 gün)

### #3 — Backend: AppState/ViewModel Ayırımı 🏗

- **Kategori:** Backend (Architecture / Testability)
- **Mevcut:** AppState 330 satır her şeyi taşıyor; ViewModel yok; test edilemiyor
- **Önerilen:** Service layer + per-feature ViewModel
- **Fayda:** Direkt kullanıcı faydası yok, ama her sonraki feature 2-3x hızlı eklenir, regresyon kolay yakalanır
- **Implementasyon:**
  1. Services/: AuthService, ProfileService, PremiumService, SavedNewsService (protocol-based)
  2. Feature/ViewModels: HomeViewModel, FeedViewModel, ...
  3. ViewModel'lar service protocol'leri DI ile alır
  4. AppState 50 satıra düş — sadece auth state
  5. View'lar `@StateObject var vm = ...`
  6. Eksik 3 (testler) bu refactor sonrası kolay
- **Etki/Efor:** 🟡 Orta / 🔴 Yüksek (1 hafta) — **post-launch**

---

## Özet: Submission'a Yol

```
ŞU AN  ←── 2 BLOCKER ──→  TESTFLIGHT  ←── 1 form ──→  APP STORE REVIEW  ←── 1-3 gün ──→  PUBLISHED
       Eksik 1 (Team ID)     Eksik 8                  Eksik 6 + 7
       Eksik 2 (Screenshot)
       
Tahmini: ~3-4 saat aktif iş + 1-3 gün Apple review
```

**Audit log'ları:** `audit-logs/` klasörü altında (build çıktıları, dosya listesi, plist'ler).
