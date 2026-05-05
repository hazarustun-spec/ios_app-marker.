import SwiftUI

// MARK: - Legal screens (in-app Privacy Policy + Terms)
enum LegalDocument: Identifiable {
    case privacy
    case terms

    var id: String { title }

    var title: String {
        switch self {
        case .privacy: return "Gizlilik Politikası"
        case .terms:   return "Kullanım Koşulları"
        }
    }

    var lastUpdated: String { "4 Mayıs 2026" }

    var sections: [LegalSection] {
        switch self {
        case .privacy: return Self.privacyContent
        case .terms:   return Self.termsContent
        }
    }
}

struct LegalSection: Identifiable {
    let id = UUID()
    let heading: String
    let body: String
}

struct LegalView: View {
    @Environment(\.dismiss) private var dismiss
    let document: LegalDocument

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(document.title)
                        .font(Font.custom("InstrumentSerif-Regular", size: 36))
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 22)
                        .padding(.top, 12)

                    Text("Son güncelleme: \(document.lastUpdated)")
                        .font(.labelSM)
                        .foregroundStyle(Color.textTertiary)
                        .tracking(0.5)
                        .padding(.horizontal, 22)
                        .padding(.top, 4)
                        .padding(.bottom, 24)

                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.heading)
                                .font(Font.custom("InstrumentSerif-Regular", size: 22))
                                .foregroundStyle(Color.textPrimary)
                                .padding(.top, 6)

                            Text(section.body)
                                .font(.bodyMD)
                                .foregroundStyle(Color(hex: "#333333"))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 18)
                    }

                    // Contact
                    VStack(alignment: .leading, spacing: 6) {
                        Text("İLETİŞİM")
                            .font(.system(size: 11, weight: .semibold).monospaced())
                            .foregroundStyle(Color.textTertiary)
                            .tracking(1.2)
                        Text("Sorular için: hazarustun@gmail.com")
                            .font(.bodySM)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .padding(.bottom, 60)
                }
            }
            .background(Color.bgPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(document.title)
                        .font(.headingMD)
                        .foregroundStyle(Color.textPrimary)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Content
extension LegalDocument {
    static let privacyContent: [LegalSection] = [
        LegalSection(
            heading: "Genel Bakış",
            body: "marker. (\"uygulama\", \"biz\"), kullanıcılarının gizliliğine saygı duyar. Bu politika, hangi verileri topladığımızı, neden topladığımızı ve nasıl kullandığımızı açıklar. Uygulamayı kullanarak bu politikayı kabul etmiş olursun."
        ),
        LegalSection(
            heading: "Topladığımız Veriler",
            body: """
            Apple ile Giriş yaptığında Apple bize sınırlı bilgi verir:
            • Apple kullanıcı kimliği (uygulama özel)
            • E-posta adresi (gizlemeyi tercih edebilirsin)
            • Adın (paylaşmayı seçtiysen)

            Uygulama kullanımı sırasında sakladığımız:
            • Seçtiğin konular ve teslimat saati
            • Kaydettiğin haberlerin listesi
            • Premium abonelik durumu
            • Bildirim için APNs token (sadece push gönderimi için)

            Kullanıcı davranışını izlemiyoruz, reklam ağlarına veri satmıyoruz, üçüncü taraf analiz aracı kullanmıyoruz.
            """
        ),
        LegalSection(
            heading: "Veriler Nasıl Saklanır",
            body: "Tüm kullanıcı verileri Supabase üzerinde, AB sunucularında, şifreli olarak saklanır (HTTPS taşıma + diskte AES-256). Veritabanı erişimi Row Level Security ile her kullanıcının yalnızca kendi kayıtlarına izin verir."
        ),
        LegalSection(
            heading: "Yapay Zekâ Üretimi İçerik",
            body: "Uygulamadaki haberler Anthropic Claude modeli tarafından otomatik olarak çoklu kaynaktan derlenir. İçerik web aramasıyla doğrulanır, ancak yapay zekâ hata yapabilir. Her haber \"AI ÜRETİMİ\" olarak işaretlenir ve gerçek kaynak URL'leri sunulur. Önemli kararları sadece bu özetlere dayandırma — birincil kaynakları kontrol et."
        ),
        LegalSection(
            heading: "Üçüncü Taraf Hizmetler",
            body: """
            Uygulama şu hizmetlerden yararlanır:
            • Apple (kimlik doğrulama, push, ödeme)
            • Supabase (veritabanı + sunucu fonksiyonları)
            • Anthropic Claude API (haber üretimi)

            Her birinin kendi gizlilik politikası vardır.
            """
        ),
        LegalSection(
            heading: "Hakların",
            body: """
            Kullanıcı olarak şu haklara sahipsin:
            • Verilerine erişim
            • Hatalı verilerin düzeltilmesi
            • Hesabını ve verilerini silme
            • Veri taşıma

            Bu hakları kullanmak için: hazarustun@gmail.com adresine yaz. 30 gün içinde yanıt veririz.
            """
        ),
        LegalSection(
            heading: "Hesap Silme",
            body: "Hesabını silmek için Ayarlar → Hesabı Sil butonunu kullanabilir veya iletişim e-postasına yazabilirsin. Silme işlemi geri alınamaz; tüm profil, kayıtlı haberler ve abonelik kayıtları kalıcı olarak silinir."
        ),
        LegalSection(
            heading: "Çocuklar",
            body: "marker. 13 yaş altı kullanıcılara yönelik değildir. 13 yaşından küçük olduğunu bildiğimiz kullanıcıların hesabı silinir."
        ),
        LegalSection(
            heading: "Politika Değişiklikleri",
            body: "Bu politika güncellenebilir. Önemli değişikliklerde uygulama içi bildirim gönderilir. Güncellenmiş politikayı kabul etmiyorsan, hesabını silebilirsin."
        ),
    ]

    static let termsContent: [LegalSection] = [
        LegalSection(
            heading: "Kabul",
            body: "marker.'ı (\"uygulama\") kullanarak bu Kullanım Koşulları'nı kabul etmiş olursun. Kabul etmiyorsan uygulamayı kullanma."
        ),
        LegalSection(
            heading: "Hizmet",
            body: "marker., yapay zekâ tarafından çoklu kaynaktan derlenmiş günlük teknoloji haber özetleri sunar. Hizmet \"olduğu gibi\" sağlanır; kesinti, hata veya gecikme olabilir."
        ),
        LegalSection(
            heading: "İçerik Sorumluluğu",
            body: """
            Uygulamadaki haberler otomatik olarak yapay zekâ tarafından üretilir. Yanlışlık, eksiklik veya yanlış yorumlama riski vardır.

            • Yatırım, sağlık, hukuk veya benzeri kararları SADECE bu özetlere göre alma.
            • Birincil kaynakları kontrol et — her haberin altındaki gerçek URL'leri kullan.
            • İçerikten doğacak zararlardan marker. sorumlu tutulamaz.
            """
        ),
        LegalSection(
            heading: "Apple ile Giriş",
            body: "Hesap oluşturmak için Apple ile Giriş zorunludur. Apple ID'nin güvenliği senin sorumluluğundadır. Hesabının yetkisiz kullanımından şüpheleniyorsan derhal bize bildir."
        ),
        LegalSection(
            heading: "Premium Abonelik",
            body: """
            Premium abonelik (aylık ₺29.99 / yıllık ₺249), Apple App Store üzerinden işletilir.
            • Otomatik yenilenir; iptal etmek için Ayarlar → Apple ID → Abonelikler.
            • Mevcut dönemin sonuna kadar Premium özellikleri kullanmaya devam edersin.
            • Apple iade politikası geçerlidir; iade taleplerin için Apple'a başvur.
            • Ücretsiz deneme süresi içinde iptal edersen ücret alınmaz.
            """
        ),
        LegalSection(
            heading: "Yasaklı Kullanım",
            body: """
            Uygulamayı şu amaçlarla kullanamazsın:
            • Yasal olmayan faaliyetler
            • Servis altyapısına saldırı, scrape, tersine mühendislik
            • İçeriği izinsiz çoğaltma veya yeniden yayınlama
            • Başka kullanıcıların hesaplarını ele geçirme
            """
        ),
        LegalSection(
            heading: "Fikri Mülkiyet",
            body: "marker. uygulaması, marka, kod ve tasarımı bizim mülkiyetimizdir. Haber içeriği orijinal kaynaklarına aittir; biz sadece özet ve derlemeyi sunuyoruz."
        ),
        LegalSection(
            heading: "Hizmet Değişiklikleri",
            body: "Hizmeti, özellikleri veya fiyatlandırmayı önceden haber vermeksizin değiştirebiliriz. Köklü değişikliklerde uygulama içi bildirim göndeririz."
        ),
        LegalSection(
            heading: "Sorumluluk Sınırı",
            body: "Yasaların izin verdiği azami ölçüde, marker. dolaylı, tesadüfi veya sonuçsal zararlardan sorumlu tutulamaz. Toplam sorumluluğumuz son 12 ayda ödediğin abonelik ücretiyle sınırlıdır."
        ),
        LegalSection(
            heading: "Geçerli Hukuk",
            body: "Bu koşullar Türkiye Cumhuriyeti hukukuna tabidir. Uyuşmazlıklar İstanbul mahkemelerinde çözülür."
        ),
        LegalSection(
            heading: "İletişim",
            body: "Sorular için: hazarustun@gmail.com"
        ),
    ]
}

#Preview("Privacy") {
    LegalView(document: .privacy)
}

#Preview("Terms") {
    LegalView(document: .terms)
}
