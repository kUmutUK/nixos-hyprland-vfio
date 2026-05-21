#!/usr/bin/env bash

# Önceki seçimi hafızada tutmak için değişken
LAST_SELECTION=""

echo "Anlık çeviri modu aktif... Seçtiğiniz metinler otomatik çevrilecek."

# wl-paste --watch yerine primary selection'ı (farenin seçtiği metni) 
# sürekli kontrol eden hafif bir döngü kuruyoruz.
while true; do
    # Fareyle seçilen güncel metni al
    CURRENT_SELECTION=$(wl-paste -p 2>/dev/null)

    # Eğer seçim boş değilse ve bir önceki seçimden farklıysa işlem yap
    if [ -n "$CURRENT_SELECTION" ] && [ "$CURRENT_SELECTION" != "$LAST_SELECTION" ]; then
        LAST_SELECTION="$CURRENT_SELECTION"
        
        # Seçilen metni translate-shell ile hızlıca Türkçeye çevir (:tr)
        # Sadece çeviriyi almak için -b (brief) modunu kullanıyoruz
        TRANSLATION=$(trans -b :tr "$CURRENT_SELECTION" 2>/dev/null)

        # Eğer çeviri başarılıysa Dunst vasıtasıyla ekranda göster
        if [ -n "$TRANSLATION" ]; then
            # -r 9999 parametresi bildirimlerin üst üste binmesini engeller, sürekli günceller
            notify-send -r 9999 "Çeviri:" "$TRANSLATION"
        fi
    fi
    # İşlemciyi yormamak için her yarım saniyede bir kontrol et
    sleep 0.5
done
