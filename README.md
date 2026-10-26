# Fast Clear

Windows için ücretsiz, açık kaynak temizlik ve optimizasyon aracı.

Windows 10 / 11 için menülü bir temizlik ve optimizasyon programı. Ek kurulum gerekmez (Windows'ta hazır gelen PowerShell ile çalışır).

## Nasıl çalıştırılır
1. `FastClear.bat` ve `FastClear.ps1` dosyalarını aynı klasöre koyun.
2. `FastClear.bat` dosyasına çift tıklayın.
3. Windows Update önbelleği, Windows Temp ve sürücü optimizasyonu için menüden **7 (Yönetici olarak yeniden başlat)** seçin.

> Windows "Bilinmeyen yayıncı" uyarısı verirse: dosyaya sağ tık > Özellikler > alttaki **Engellemeyi kaldır** kutusunu işaretleyin.

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
- Her silme işlemi `logs` klasörüne kaydedilir.
- Tarayıcı önbelleği temizlenirken tarayıcıları kapatmanız önerilir.
