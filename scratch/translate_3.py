import json
import re

def tr(text):
    if not isinstance(text, str): return text
    # Exact phrases
    phrases = {
        "Xoş gəlmisiniz": "Hoş geldiniz",
        "Zolaq": "Çubuk",
        "Başladıcı": "Başlatıcı",
        "Uygulama rəfi": "Uygulama Rafı",
        "Ekran göstəricisi": "Ekran Göstergeleri",
        "Bildirişlər": "Bildirimler",
        "Rəqəmsal rifah": "Dijital Denge",
        "Fəaliyyətsizlik": "Boşta",
        "Yazı növü": "Yazı Tipi",
        "Fon şəkilləri qovluğu": "Duvar Kağıtları Klasörü",
        "Fon şəkillərinin axtarılacağı qovluq": "Duvar kağıtlarının aranacağı klasör",
        "Künclərin radiusu": "Köşe kavisleri",
        "İnterfeys elementlərinin künc radiusu": "Arayüz elemanlarının köşe yuvarlaklığı",
        "Renk mövzuları": "Renk Temaları",
        "Vidcetlər": "Widgetlar",
        "Təlimat": "Eğitim",
        "Güncellemə": "Güncelleme",
        "Güncəlləmə": "Güncelleme",
        "Haqqında": "Hakkında",
        "Modullar": "Modüller",
        "Yan modullar": "Yan Modüller",
        "Bəli": "Evet",
        "Xeyr": "Hayır",
        "Yüklənir": "Yükleniyor",
        "Ləğv et": "İptal Et",
        "Ləğv": "İptal",
        "Tətbiq et": "Uygula",
        "Tətbiqlər": "Uygulamalar",
        "Ayarlar": "Ayarlar",
        "Şəbəkə": "Ağ",
        "Səs": "Ses",
        "Parlaqlıq": "Parlaklık",
        "Axtar": "Ara",
        "Yenilə": "Yenile",
        "Dəyişdir": "Değiştir",
        "Əlavə et": "Ekle",
        "Sil": "Sil",
        "Saxla": "Kaydet",
        "İmtina": "İptal",
        "Geri": "Geri",
        "İrəli": "İleri",
        "Qoşul": "Bağlan",
        "Qoşulub": "Bağlandı",
        "Qoşulur": "Bağlanıyor",
        "Bağlıdır": "Bağlı",
        "Açıqdır": "Açık",
        "Naməlum": "Bilinmeyen",
        "Aktiv": "Aktif",
        "Deaktiv": "Pasif",
        "Səviyyə": "Seviye",
        "Ekran": "Ekran",
        "Görünüş": "Görünüm",
        "Mövzu": "Tema",
        "Arxa plan": "Arka Plan",
        "Şəkil": "Resim",
        "Saat": "Saat",
        "Gün": "Gün",
        "Həftə": "Hafta",
        "Ay": "Ay",
        "İl": "Yıl",
        "Daxil ol": "Giriş yap",
        "Çıxış": "Çıkış",
        "Şifrə": "Şifre",
        "Ad": "Ad",
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
    
    for k, v in phrases.items():
        text = text.replace(k, v)
        text = text.replace(k.lower(), v.lower())
        
    # Letter level (only for words that still have strict azeri chars)
    # text = text.replace("ə", "e").replace("Ə", "E")
    # text = text.replace("q", "k").replace("Q", "K")
    # text = text.replace("x", "h").replace("X", "H")
    
    return text

def process(obj):
    if isinstance(obj, str):
        return tr(obj)
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
except Exception as e:
    print(e)
print("Done")
