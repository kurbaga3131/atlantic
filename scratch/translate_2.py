import json

with open("c:/Users/kravor-x/Downloads/atlantic/src/assets/languages/tr.json", "r", encoding="utf-8") as f:
    data = json.load(f)

replacements = {
    "Xoş gəlmisiniz": "Hoş geldiniz",
    "Zolaq": "Çubuk (Bar)",
    "Başladıcı": "Başlatıcı",
    "Uygulama rəfi": "Uygulama Rafı",
    "Ekran göstəricisi": "Ekran Göstergeleri",
    "Bildirişlər": "Bildirimler",
    "Rəqəmsal rifah": "Dijital Denge",
    "Fəaliyyətsizlik": "Boşta (Idle)",
    "Yazı növü": "Yazı Tipi (Font)",
    "Fon şəkilləri qovluğu": "Duvar Kağıtları Klasörü",
    "Fon şəkillərinin axtarılacağı qovluq": "Duvar kağıtlarının aranacağı klasör",
    "atlantic üçün standart yazı növünü seçin": "Sistem için standart yazı tipini seçin",
    "Künclərin radiusu": "Köşe kavisleri (Radius)",
    "İnterfeys elementlərinin künc radiusu": "Arayüz elemanlarının köşe yuvarlaklığı",
    "Renk mövzuları": "Renk Temaları",
    "Hazır rəng palitrası seçin və ya öz mövzunuzu yaradın.": "Hazır renk paleti seçin veya kendi temanızı oluşturun."
}

def replace_recursive(obj):
    if isinstance(obj, str):
        for k, v in replacements.items():
            if k in obj:
                obj = obj.replace(k, v)
        return obj
    elif isinstance(obj, dict):
        return {k: replace_recursive(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [replace_recursive(v) for v in obj]
    return obj

new_data = replace_recursive(data)

with open("c:/Users/kravor-x/Downloads/atlantic/src/assets/languages/tr.json", "w", encoding="utf-8") as f:
    json.dump(new_data, f, ensure_ascii=False, indent=2)

print("Done")
