import json

def process(obj):
    phrases = {
        "Cihazın adı": "Cihaz Adı",
        "Prossesor": "İşlemci",
        "Qrafika": "Grafik",
        "Yaddaş": "Bellek",
        "Diskin tutumu": "Disk Kapasitesi",
        "Əməliyyat sistemi": "İşletim Sistemi",
        "Nüvənin versiyası": "Çekirdek Sürümü",
        "İş masası": "Masaüstü",
        "Qabıq": "Kabuk",
        "İşləmə müddəti": "Çalışma Süresi",
        "Bilinmeyen": "Bilinmiyor",
        "Müəllif": "Yazar",
        "müəllif": "yazar",
        "Versiya": "Sürüm",
        "Yeniləmə mövcuddur": "Güncelleme mevcut",
        "Yeniləmə yoxdur": "Güncelleme yok",
        "Yeniləməni yoxla": "Güncellemeleri kontrol et",
        "Yeniləmə": "Güncelleme",
        "Yüklə": "İndir",
        "Quraşdır": "Kur",
        "Quraşdırılır": "Kuruluyor",
        "Quraşdırıldı": "Kuruldu",
        "Xəta": "Hata",
        "Uğurlu": "Başarılı",
        "Davam et": "Devam et",
        "Dayandır": "Durdur",
        "Bəli": "Evet",
        "Xeyr": "Hayır",
        "Ləğv et": "İptal",
        "Tətbiq et": "Uygula",
        "Axtarış": "Arama",
        "Axtar": "Ara",
        "Daxil ol": "Giriş yap",
        "Çıxış": "Çıkış",
        "Ayarlar": "Ayarlar",
        "Şəbəkə": "Ağ",
        "Səs": "Ses",
        "Ekran": "Ekran",
        "Görünüş": "Görünüm",
        "Mövzu": "Tema",
        "Arxa plan": "Arka Plan",
        "Şəkil": "Resim",
        "Fayl": "Dosya",
        "Qovluq": "Klasör",
        "Ümumi": "Genel",
        "Ətraflı": "Detaylı",
        "Seçimlər": "Seçenekler",
        "Dəyişikliklər": "Değişiklikler",
        "Sistem": "Sistem",
        "Cihaz": "Cihaz",
        "Tənzimləmələr": "Ayarlar"
    }
    
    if isinstance(obj, str):
        for k, v in phrases.items():
            obj = obj.replace(k, v)
        return obj
    elif isinstance(obj, dict):
        return {k: process(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [process(v) for v in obj]
    return obj

try:
    with open("c:/Users/kravor-x/Downloads/atlantic/src/assets/languages/tr.json", "r", encoding="utf-8") as f:
        data = json.load(f)
        
    data = process(data)
    
    with open("c:/Users/kravor-x/Downloads/atlantic/src/assets/languages/tr.json", "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("Done")
except Exception as e:
    print(e)
