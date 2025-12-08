#!/bin/bash

SRC="/mnt/f/Downloads/Movies"
DEST="$HOME/media/movies"
LOGFILE="$HOME/media/move.log"

echo "=== MULAI PEMINDAHAN FILE ===" | tee -a "$LOGFILE"
echo "Sumber      : $SRC" | tee -a "$LOGFILE"
echo "Tujuan      : $DEST" | tee -a "$LOGFILE"
echo "Log file    : $LOGFILE" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

# Pastikan folder tujuan ada
mkdir -p "$DEST"

# Loop per file
for file in "$SRC"/*; do
    # Jika tidak ada file, stop
    [ -e "$file" ] || { echo "Tidak ada file untuk dipindahkan."; exit 0; }

    filename=$(basename "$file")

    # Jika file sudah ada di tujuan → skip
    if [ -e "$DEST/$filename" ]; then
        echo "[SKIP] File sudah ada: $filename" | tee -a "$LOGFILE"
        continue
    fi

    # Log mulai
    echo "Sedang memindahkan $filename..." | tee -a "$LOGFILE"

    # Pindahkan file
    mv "$file" "$DEST"/
    
    # Cek berhasil atau tidak
    if [ $? -eq 0 ]; then
        echo "✔️  $filename selesai dipindahkan." | tee -a "$LOGFILE"
    else
        echo "❌  Gagal memindahkan $filename." | tee -a "$LOGFILE"
    fi

    echo "" | tee -a "$LOGFILE"
done

echo "=== SEMUA PROSES SELESAI ===" | tee -a "$LOGFILE"
