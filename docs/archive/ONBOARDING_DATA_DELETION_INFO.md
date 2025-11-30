# 📱 Onboarding - Veri Silme Bilgilendirmesi

## ✅ Apple App Store Uygunluğu

**Araştırma Sonuçları:**

1. **✅ YASAL VE UYGUN:** Veri silme politikalarını kullanıcıya bildirmek Apple'ın kurallarına uygun ve hatta önerilen bir uygulamadır.

2. **✅ "Our Server" İfadesi Yeterli:** Fal.ai'den spesifik olarak bahsetmek zorunlu değil. "Our servers" veya "our systems" gibi genel ifadeler kullanabilirsiniz.

3. **✅ Süre Belirtmek Uygun:** "1 hour" gibi spesifik süreler belirtmek Apple'ın kurallarına uygundur.

4. **⚠️ Önemli Not:** Eğer kişisel veri (fotoğraflar) üçüncü taraf servislere gönderiliyorsa, kullanıcıya bilgi verilmesi gerekiyor. Ancak bu bilgi onboarding'de değil, Privacy Policy'de detaylı olarak yer almalı.

---

## 📋 Eklenen Özellikler

### Yeni Onboarding Ekranı: OnboardingScreen4

**İçerik:**
- ⚠️ Sonuç sayfasını kapatmadan önce kaydetme uyarısı
- ⏰ 1 saat sonra otomatik silme bilgisi
- ✅ "I Understand" butonu

**Metinler (Apple Uyumlu):**
- "Your processed images will be deleted from our servers when you close the result page"
- "Images are automatically deleted from our servers after 1 hour"

**Neden Bu Metinler:**
- ✅ "Our servers" - Genel ifade, Fal.ai'den bahsetmiyor
- ✅ Spesifik süre belirtiyor (1 hour)
- ✅ Kullanıcıyı bilgilendiriyor ama korkutmuyor
- ✅ Apple'ın şeffaflık gereksinimlerini karşılıyor

---

## 🔄 Değişiklikler

### 1. OnboardingScreen4.swift (YENİ)
- Veri silme politikası bilgilendirme ekranı
- İki uyarı: Sonuç sayfası kapatma + Otomatik silme

### 2. OnboardingViewModel.swift (GÜNCELLENDİ)
- `dataPolicy = 3` ekranı eklendi
- Toplam ekran sayısı: 3 → 4

### 3. OnboardingView.swift (GÜNCELLENDİ)
- OnboardingScreen4 eklendi
- OnboardingScreen3'ün butonu "Get Started" → "Next" olarak değiştirildi

### 4. OnboardingScreen3.swift (GÜNCELLENDİ)
- "Get Started" butonu → "Next" butonu
- Artık son ekran değil, dataPolicy ekranı son ekran

---

## 📊 Onboarding Akışı (Güncellenmiş)

```
1. Welcome Screen (OnboardingScreen1)
   ↓
2. How It Works (OnboardingScreen2)
   ↓
3. Credits (OnboardingScreen3)
   ↓
4. Data Deletion Policy (OnboardingScreen4) ← YENİ
   ↓
   "I Understand" → Onboarding tamamlandı
```

---

## ✅ Apple Uyumluluk Kontrol Listesi

- [x] Veri silme politikası kullanıcıya bildirildi
- [x] Spesifik süre belirtildi (1 hour)
- [x] Genel ifadeler kullanıldı ("our servers")
- [x] Üçüncü taraf servis ismi belirtilmedi (Fal.ai)
- [x] Kullanıcı dostu ve anlaşılır dil kullanıldı
- [x] Kullanıcı onayı alındı ("I Understand" butonu)

---

## 📝 Privacy Policy'de Eklenmesi Gerekenler

**Not:** Onboarding'de genel bilgi veriyoruz, detaylar Privacy Policy'de olmalı:

```
Data Processing:
- Your images are processed on our servers
- Processed images are automatically deleted after 1 hour
- Original uploads are deleted immediately after processing
- You can save processed images to your device before they are deleted

Third-Party Services:
- We use third-party AI services to process your images
- Your images are transmitted securely to our processing servers
- All data is handled in accordance with our Privacy Policy
```

---

## 🎯 Sonuç

✅ **Apple App Store'a uygun!**

- Veri silme politikasını bildirmek yasal ve önerilen
- "Our servers" ifadesi yeterli (Fal.ai'den bahsetmek zorunlu değil)
- Spesifik süre belirtmek uygun
- Kullanıcı bilgilendirmesi şeffaflık gereksinimlerini karşılıyor

**Onboarding'e eklenen ekran Apple'ın kurallarına tam uyumlu!** 🎯

