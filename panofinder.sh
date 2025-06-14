#!/bin/bash
#####################################################################
#
#      Искатель фоток по форме (ПАНОРАМЫ / КВАДРАТЫ / 3x4 / 3x2 /
#      - отсекает мелкие превью (задается минимальный вес MIN_SIZE="+500k")
#      - задаются пропорции для фильтра поиска
               # {2:-2.8} - панорама (2 2.8 = прямоугольник)
               # {1:-1}   - insta (1 к 1 = квадрат)
#
#      Зависимости: sudo apt install parallel exiftool 
#
#      Запускать из текущей папки
#      ./panofinder.sh
#      panoramas.log - найденые панорамы
#      debug.log     - дебаг
#      metadata.txt  - метадата
#
#      v0.1 |	2025.06.12
#####################################################################

   SEARCH_DIR="${1:-.}"
    MIN_RATIO="${2:-2.8}"
              #{2:-2.8} - pano
              #{1:-1}   - insta
     MIN_SIZE="+500k"   # 500kb 
    MIN_SIZE2="512000"  # 512000=500kb
     LOG_FILE="panoramas.log"
    DEBUG_LOG="debug.log"
METADATA_FILE="metadata.txt"

#####################################################################
total_files=0
panorama_count=0
start_time=$(date +%s)

> "$LOG_FILE"
> "$DEBUG_LOG"
> "$METADATA_FILE"

if ! command -v exiftool >/dev/null 2>&1; then
    echo "Ошибка: exiftool не установлен. Установите: sudo apt install libimage-exiftool-perl" >&2
    exit 1
fi

echo "Извлечение метаданных из $SEARCH_DIR..."
exiftool -s3 -n -ImageWidth -ImageHeight -filesize# -if '$filesize >= '"$MIN_SIZE2" "$SEARCH_DIR" -r -ext jpg -ext jpeg > "$METADATA_FILE" 2>>"$DEBUG_LOG"
echo "$(date '+%Y-%m-%d %H:%M:%S'): Метаданные сохранены в $METADATA_FILE" >> "$DEBUG_LOG"

echo "Поиск панорам с соотношением сторон >= $MIN_RATIO в $SEARCH_DIR..."
awk -v min_ratio="$MIN_RATIO" -v min_size="$MIN_SIZE2" '
BEGIN { file=""; width=0; height=0; filesize=0; line_count=0 }
/^========/ {
    if (file != "" && width > 0 && height > 0 && filesize >= min_size) {
        if (width >= height) {
            ratio = width / height;
            orientation = "горизонтальная";
        } else {
            ratio = height / width;
            orientation = "вертикальная";
        }
        if (ratio >= min_ratio) {
            printf "Найдена панорама: %s (%s, размеры: %d x %d, соотношение: %.2f)\n", file, orientation, width, height, ratio;
            print "Панорама: " file " (" width " x " height ", соотношение: " sprintf("%.2f", ratio) ")" >> "'"$LOG_FILE"'";
            print strftime("%Y-%m-%d %H:%M:%S") ": Найдена панорама: " file >> "'"$DEBUG_LOG"'";
            panorama_count++;
        } else {
            printf "Отклонено: %s (%s, размеры: %d x %d, соотношение: %.2f)\n", file, orientation, width, height, ratio;
            print strftime("%Y-%m-%d %H:%M:%S") ": Отклонено: " file >> "'"$DEBUG_LOG"'";
        }
        total_files++;
    }
    file = substr($0, 10); # Убираем "======== "
    width = 0; height = 0; filesize = 0; line_count = 0;
}
/^[0-9]+$/ {
    line_count++;
    if (line_count == 1) width = $1;
    if (line_count == 2) height = $1;
    if (line_count == 3) filesize = $1;
}
END {
    if (file != "" && width > 0 && height > 0 && filesize >= min_size) {
        if (width >= height) {
            ratio = width / height;
            orientation = "горизонтальная";
        } else {
            ratio = height / width;
            orientation = "вертикальная";
        }
        if (ratio >= min_ratio) {
            printf "Найдена панорама: %s (%s, размеры: %d x %d, соотношение: %.2f)\n", file, orientation, width, height, ratio;
            print "Панорама: " file " (" width " x " height ", соотношение: " sprintf("%.2f", ratio) ")" >> "'"$LOG_FILE"'";
            print strftime("%Y-%m-%d %H:%M:%S") ": Найдена панорама: " file >> "'"$DEBUG_LOG"'";
            panorama_count++;
        } else {
            printf "Отклонено: %s (%s, размеры: %d x %d, соотношение: %.2f)\n", file, orientation, width, height, ratio;
            print strftime("%Y-%m-%d %H:%M:%S") ": Отклонено: " file >> "'"$DEBUG_LOG"'";
        }
        total_files++;
    }
    print total_files > "/tmp/total_files";
    print panorama_count > "/tmp/panorama_count";
}' "$METADATA_FILE"

total_files=$(cat /tmp/total_files)
panorama_count=$(cat /tmp/panorama_count)
rm -f /tmp/total_files /tmp/panorama_count

end_time=$(date +%s)
duration=$((end_time - start_time))
minutes=$((duration / 60))
seconds=$((duration % 60))

echo "----------------------------------------"
echo "Отчет:"
echo "Скрипт работал: $minutes мин. $seconds сек."
echo "Обработано: $total_files файлов"
echo "Найдено: $panorama_count панорам"
echo "Список панорам сохранен в: $LOG_FILE"
echo "Отладочный лог: $DEBUG_LOG"
echo "----------------------------------------"
