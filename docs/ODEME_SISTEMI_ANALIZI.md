# Ödeme Sistemi Analizi ve Çözüm Raporu 🍌

Bu belge, **BananaUniverse** uygulamasının ödeme sisteminin mevcut durumunu, tespit edilen kritik hataları ve çözüm önerilerini kapsamlı bir şekilde analiz eder.

---

## 1. Mevcut Durum ve İşleyiş (Current Flow)

Uygulamanız **StoreKit 2** (Apple'ın modern ödeme altyapısı) ve **Supabase Edge Functions** kullanmaktadır.

### 📱 iOS Tarafı (`StoreKitService.swift`)
1.  Kullanıcı "Satın Al" butonuna basar.
2.  Apple StoreKit araya girer ve ödemeyi alır (`product.purchase()`).
3.  Ödeme başarılı olursa, Apple bir `Transaction` (işlem) nesnesi döner.
4.  Uygulama bu işlemin `id`'sini (Transaction ID) alır.
5.  **Kritik Nokta:** Uygulama, bu `transaction_id`'yi ve `product_id`'yi alarak Backend'e (`verify-iap-purchase`) gönderir.

### ☁️ Backend Tarafı (`verify-iap-purchase/index.ts`)
1.  Gelen isteği karşılar.
2.  Kullanıcıyı tanımaya çalışır (Giriş yapmış mı, yoksa anonim mi?).
3.  İşlem detaylarını (Transaction ID) kullanarak Apple'a "Bu işlem gerçek mi?" diye sorar.
4.  Apple "Evet" derse, veritabanına krediyi ekler.
5.  Telegram'a bildirim atar.

---

## 2. Tespit Edilen 4 Kritik Hata 🚨

Mevcut backend kodunda, sistemin çalışmasını engelleyen **4 ölümcül hata** bulunmaktadır. Bu kod şu haliyle canlıya alınırsa ödemeler başarısız olur.

### ❌ Hata 1: "Mektubu İki Kez Açmaya Çalışmak" (Double Body Parsing)
*   **Sorun:** Kod, gelen isteğin içeriğini (`req.json()`) iki kez okumaya çalışıyor. İlk okumada içerik tüketilir, ikinci okumada kod patlar.
*   **Sonuç:** Anonim (giriş yapmamış) kullanıcılar ödeme yapmaya çalıştığında **sistem çöker**.

### ❌ Hata 2: "Olmayan Şeyi Kesmeye Çalışmak" (Undefined JWT)
*   **Sorun:** Kod, veritabanına kayıt atarken `transaction_jwt` isimli bir verinin ilk 100 karakterini kesmeye çalışıyor (`substring`).
*   **Gerçek:** iOS uygulamanız modern **StoreKit 2** kullandığı için `transaction_jwt` göndermiyor, sadece `transaction_id` gönderiyor.
*   **Sonuç:** `transaction_jwt` tanımsız (undefined) olduğu için kod **hata verir ve işlem iptal olur**. Kullanıcı parasını öder ama kredisini alamaz.

### ❌ Hata 3: "Eksik Veri Kontrolü" (Missing Null Checks)
*   **Sorun:** Kod, Apple'dan gelen yanıtın her zaman eksiksiz olduğunu varsayıyor. `original_transaction_id` gibi kritik verilerin boş gelme ihtimali kontrol edilmiyor.
*   **Sonuç:** Nadir durumlarda veritabanına bozuk veri yazılır veya işlem hatalı anahtarla kaydedilir (`purchase-undefined`).

### ❌ Hata 4: "Veritabanı Uyumsuzluğu" (Database Constraints)
*   **Sorun:** Kullanıcı ID veya Cihaz ID'si boş (null) geldiğinde, veritabanı ayarlarınıza bağlı olarak kayıt reddedilebilir.
*   **Sonuç:** Kredi verilse bile işlem kaydı tutulamayabilir.

---

## 3. İdeal Ödeme Akışı Nasıl Olmalı? ✨

Sizin uygulamanız için en sağlıklı ve "Best Practice" akış şudur (Şu an kurduğunuz yapı buna çok yakın, sadece hataların temizlenmesi lazım):

1.  **Müşteri Öder:** iOS uygulaması Apple üzerinden parayı çeker.
2.  **Kanıt Gönderilir:** iOS, sadece `transaction_id` (fiş numarası) bilgisini Backend'e yollar. (JWT ile uğraşmaz, en temizi budur).
3.  **Doğrulama:** Backend, bu fiş numarasını alıp Apple'a sorar: "Bu fiş geçerli mi?"
4.  **Kredi Yükleme:** Apple onaylarsa, Backend kullanıcının hesabına krediyi işler.
5.  **Yanıt:** Backend, iOS'a "Tamamdır, krediyi yükledim" der.
6.  **Kapanış:** iOS, Apple'a "İşlem bitti" (`finish`) bilgisini verir.

---

## 4. Çözüm ve Yol Haritası 🛠️

Bu sistemi düzeltmek için yapmamız gereken tek şey **Backend kodunu (`verify-iap-purchase/index.ts`) tamir etmektir.** iOS tarafındaki kodunuz gayet düzgün çalışıyor (StoreKit 2'yi doğru kullanıyorsunuz).

**Yapılacak Düzeltmeler:**
1.  **Tek Seferlik Okuma:** İstek gövdesini (`body`) en başta bir değişkene alıp, her yerde o değişkeni kullanacağız.
2.  **Güvenli Kontrol:** `transaction_jwt` yoksa onu kesmeye çalışmayacağız.
3.  **Sağlamlaştırma:** Tüm veri girişlerini (null check) kontrol edeceğiz.

### Sonuç
Bu düzeltmeleri uyguladığımızda:
*   ✅ Anonim kullanıcılar sorunsuz kredi alabilecek.
*   ✅ Giriş yapmış kullanıcılar sorunsuz kredi alabilecek.
*   ✅ Veritabanına tüm işlemler eksiksiz kaydedilecek.
*   ✅ Siz her satışta Telegram bildirimi alacaksınız.

**Onayınızla birlikte bu düzeltmeleri şimdi uygulayabilirim.**

