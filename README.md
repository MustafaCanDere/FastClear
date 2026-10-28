# Fast Clear

Windows için ücretsiz, açık kaynak temizlik ve optimizasyon aracı.

Windows 10 / 11 için menülü bir temizlik ve optimizasyon programı. Kurulum gerekmez.

[![Derleme](https://github.com/MustafaCanDere/FastClear/actions/workflows/build.yml/badge.svg)](https://github.com/MustafaCanDere/FastClear/actions/workflows/build.yml)

## İndir ve çalıştır
1. **[Son sürümü indir (Releases)](https://github.com/MustafaCanDere/FastClear/releases/latest)** ve `FastClear.exe` dosyasını kaydet.
2. `FastClear.exe` dosyasına çift tıkla. Windows yönetici izni ister; **Evet** de (Windows Temp, Update önbelleği ve sürücü optimizasyonu için gerekli).

> Program imzasız olduğu için Windows SmartScreen "Bilinmeyen yayımcı" uyarısı gösterebilir. **Ek bilgi > Yine de çalıştır** ile açabilirsin. Kaynak kodun tamamı bu depodadır (`FastClear.ps1`).

Kayıtlar `%LOCALAPPDATA%\FastClear\logs` klasörüne yazılır.

## Menü
| No | İşlem | Siler mi? |
|----|-------|-----------|
| 1 | Sistem ve disk raporu (RAM, disk doluluk, en çok bellek kullanan işlemler) | Hayır |
| 2 | Önemsiz dosya taraması – ne kadar yer açılacağını gösterir | Hayır |
| 3 | Temizle – kategori seçersiniz, liste gösterilir, **onay verirseniz** siler | Evet (onaylı) |
| 4 | Başlangıçta açılan programları listeler, Görev Yöneticisi'ni açar | Hayır |
| 5 | Kullanıcı klasörünüzdeki büyük dosyaları bulur | Hayır |
| 6 | DNS temizleme, SSD TRIM / HDD birleştirme, Disk Temizleme, Depolama Algısı | Hayır |

## Temizlenen kategoriler
1. Kullanıcı geçici dosyaları (24 saatten eski olanlar)
2. Windows geçici dosyaları (yönetici)
3. Tarayıcı önbellekleri – Chrome, Edge, Firefox, Brave, Opera, Vivaldi (şifre, geçmiş ve çerezler **silinmez**)
4. Windows Update indirme önbelleği (yönetici)
5. Hata raporları ve çökme dökümleri
6. Küçük resim (thumbnail) önbelleği
7. DirectX gölgelendirici önbelleği
8. Geri Dönüşüm Kutusu

## Güvenlik
- Kişisel dosyalara, belgelere, kayıt defterine dokunmaz.
- Kullanımdaki dosyalar atlanır, hata vermez.
- Her silme işlemi `%LOCALAPPDATA%\FastClear\logs` klasörüne kaydedilir.
- Tarayıcı önbelleği temizlenirken tarayıcıları kapatmanız önerilir.
