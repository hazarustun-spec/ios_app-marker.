# marker. — Daily AI News Brief (iOS)

> Her sabah, yapay zekâ tarafından çoklu kaynaktan derlenmiş 6 önemli haber. 5 dakika oku, gün boyu güncel kal.

[![iOS](https://img.shields.io/badge/iOS-17.0+-black.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-Private-red.svg)](LICENSE)

## Genel Bakış

**marker.** Apple App Store için hazırlanan, günlük yapay zekâ haber özeti sunan bir iOS uygulamasıdır. İçerik Anthropic Claude (`claude-sonnet-4-6`) tarafından gerçek web kaynaklarından otomatik olarak derlenir, her gün saat **06:30 İstanbul** itibarıyla telefonlara teslim edilir.

### Ürün Özellikleri

- 10 kategori (LLM'ler, Robotik, Araştırma, AI Güvenliği, Görsel AI, Araçlar, Ekonomi, Politika, Üretken AI, Sağlık)
- Sign in with Apple
- Premium abonelik (StoreKit 2): 10 konunun hepsi, sınırsız kayıt
- Push bildirimi (kullanıcının seçtiği saatte)
- Yer imi senkronizasyonu (cihazlar arası)
- Türkçe UI ve içerik

## Mimari

```
┌────────────────────────────────────────────┐
│ iOS App (SwiftUI, iOS 17+)                  │
│  • OnboardingView, HomeView, FeedView,      │
│    SavedView, SettingsView, NewsDetailView, │
│    PaywallView, LegalView                   │
│  • AppState (@MainActor ObservableObject)   │
│  • Singleton services: Supabase, StoreKit,  │
│    Notifications, Sentry                    │
└──────────────┬─────────────────────────────┘
               │ HTTPS + JWT
               ▼
┌────────────────────────────────────────────┐
│ Supabase                                    │
│  • Postgres (5 tablo, RLS)                  │
│  • Auth (Apple Sign-In provider)            │
│  • Edge Functions (Deno):                   │
│      generate-daily-news                    │
│      admin-news                             │
└──────────────┬─────────────────────────────┘
               │
               ▼
┌────────────────────────────────────────────┐
│ Anthropic Claude API + Web Search Tool     │
│  • claude-sonnet-4-6                        │
│  • web_search_20250305                      │
│  • Structured output (publish_article tool) │
└────────────────────────────────────────────┘
```

## Tech Stack

| Katman | Teknoloji |
|---|---|
| iOS | Swift 5.9, SwiftUI, iOS 17.0+ |
| Backend | Supabase (Postgres + Edge Functions) |
| AI | Anthropic Claude (web search ile) |
| Auth | Sign in with Apple → Supabase Auth |
| Payments | StoreKit 2 |
| Push | APNs (production) |
| Crash | Sentry |
| Build | xcodegen + SPM |
| CI/CD | GitHub Actions (cron + reconciliation) |
| Admin | Static HTML dashboard (`admin-dashboard/index.html`) |

## Proje Yapısı

```
AINewsApp/
├── project.yml                    # xcodegen kaynak dosyası
├── Configuration.storekit         # Local IAP test config
├── Sources/AINewsApp/
│   ├── App/                       # Entry point + Info.plist + Entitlements + PrivacyInfo
│   ├── Core/                      # Models, Network, Util
│   │   ├── Models/                # NewsItem, Topic, UserProfile
│   │   ├── Network/               # SupabaseManager, DatabaseModels
│   │   └── Util/                  # Log
│   ├── Components/                # Reusable UI (BriefLogo, NewsCard, JustifiedText, ...)
│   ├── Features/                  # Per-screen view + logic
│   │   ├── Onboarding/
│   │   ├── Home/                  # HomeView + NewsDetailView
│   │   ├── Feed/
│   │   ├── Saved/
│   │   ├── Settings/
│   │   ├── Paywall/
│   │   └── Legal/
│   └── Services/                  # NotificationManager, StoreKitManager
├── Resources/                     # Fonts + Assets.xcassets
├── Tests/AINewsAppTests/          # XCTest unit tests
├── Supabase/
│   ├── schema.sql                 # DB schema (5 tablo + RLS)
│   └── functions/
│       ├── generate-daily-news/   # Cron-triggered news generator
│       └── admin-news/            # Admin CRUD (password-protected)
├── admin-dashboard/index.html     # Browser-based content management
├── fastlane/                      # CI/CD automation
└── audit-logs/                    # Release audit artifacts
```

## Geliştirme Kurulumu

### Önkoşullar

- **Xcode 16.0+**
- **macOS 14+** (Apple Silicon önerilir)
- **xcodegen**: `brew install xcodegen`
- **Apple Developer Program** üyeliği (signing için)
- (Opsiyonel) **sentry-cli**: `brew install getsentry/tools/sentry-cli`
- (Opsiyonel) **fastlane**: `brew install fastlane`
- (Opsiyonel) **supabase CLI**: `brew install supabase/tap/supabase`

### Kurulum

```bash
git clone https://github.com/hazarustun-spec/AINewsApp.git
cd AINewsApp
xcodegen generate
open AINewsApp.xcodeproj
```

### Apple Developer Team ID Kurulumu

`project.yml:12` satırındaki `DEVELOPMENT_TEAM` boş. Kendi Team ID'ni ekle:

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: "ABCDE12345"   # ← Apple Developer Portal'dan
```

Sonra `xcodegen generate` ile projeyi yeniden oluştur.

### Build & Run

```bash
# Simulator için
xcodebuild -scheme AINewsApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' build

# Test çalıştır
xcodebuild test -scheme AINewsApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'

# Release archive
xcodebuild -scheme AINewsApp -configuration Release -destination 'generic/platform=iOS' archive
```

Veya `fastlane` ile:

```bash
fastlane ios test       # Testleri çalıştır
fastlane ios beta       # TestFlight'a yükle
```

## Backend (Supabase)

### Schema Deploy

```bash
psql -h <supabase-host> -U postgres -d postgres -f Supabase/schema.sql
```

### Edge Functions

```bash
# Deploy generate-daily-news
supabase functions deploy generate-daily-news --no-verify-jwt --project-ref <project-ref>

# Deploy admin-news
supabase functions deploy admin-news --no-verify-jwt --project-ref <project-ref>
```

### Gerekli Supabase Secrets

```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-... --project-ref <project-ref>
supabase secrets set ADMIN_PASSWORD=<güçlü-şifre> --project-ref <project-ref>
supabase secrets set APNS_KEY_ID=... --project-ref <project-ref>
supabase secrets set APNS_TEAM_ID=... --project-ref <project-ref>
supabase secrets set APNS_PRIVATE_KEY="$(cat AuthKey.p8)" --project-ref <project-ref>
supabase secrets set APNS_BUNDLE_ID=com.hazarustun.ainewsapp --project-ref <project-ref>
```

## Otomatik Üretim Mimarisi

```
05:00 IST  ──┐
05:20 IST    │  GitHub Actions cron'lar
05:40 IST    │  Reconciliation: yalnızca eksik
06:00 IST    │  topic'leri işler (idempotent)
06:20 IST  ──┘  ← Final guarantee window
06:30 IST  ▼ Telefonlara teslim
```

**Garanti:** 06:30 İstanbul itibarıyla 10/10 topic DB'de hazır.

**Reconciliation cron** her başladığında:
1. DB'ye sorar — bugün hangi topic eksik?
2. Sadece eksikleri işler (DB unique constraint koruyucu)
3. Hâlâ eksik kalan varsa sonraki cron alır

**2 katmanlı içerik üretim stratejisi:**
1. **Specific** — `web_search` ile son 7 gün topic'e dar haber
2. **Broader** — başarısız olursa son 14 gün geniş arama

Her iki katman da gerçek web search ile gerçek source URL'si zorunlu kılar. Placeholder/explainer içerik **YOK**.

## Admin Dashboard

`admin-dashboard/index.html`'i tarayıcıda aç (veya GitHub Pages'e deploy et). Şifreyle giriş, sonra:

- Tarih × topic ızgarasında bugünün ve geçmişin haberlerini gör
- Çoklu gün Excel görünümü
- Manuel haber ekle / düzenle / sil
- "⚡ Yeniden üret" butonu — Claude'a bir topic'i yeniden üretmesini söyler

## Test

```bash
xcodebuild test -scheme AINewsApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'
```

Mevcut test target'ı `Tests/AINewsAppTests/`:
- `AppStateTests.swift` — auth + onboarding + topic seçim mantığı
- `PremiumGatingTests.swift` — `canFullyRead` (free vs premium)
- `CardToneTests.swift` — UI renk eşleşmesi

## Release / TestFlight

Detaylı süreç için bkz: [`RELEASE_AUDIT.md`](RELEASE_AUDIT.md)

```bash
fastlane ios beta   # Archive + upload to TestFlight
```

## Yasal

- [Gizlilik Politikası](https://hazarustun-spec.github.io/marker-legal/privacy.html)
- [Kullanım Koşulları](https://hazarustun-spec.github.io/marker-legal/terms.html)

## Katkı

Bu private bir repo. İletişim: hazarustun@gmail.com

## Lisans

© 2026 Hazar Üstün — Tüm hakları saklıdır.
