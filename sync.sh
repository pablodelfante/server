#!/bin/bash
# Define los directorios a sincronizar
SOURCE_DIR="$HOME/Documents"
DEST_DIR="/mnt/backups"
LOG_DIR="$HOME/Documents/server_logs"
LOG_FILE="$LOG_DIR/sync_$(date +%Y%m%d_%H%M%S).log"


# Asegúrate de que los directorios existan
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: El directorio de origen no existe ($SOURCE_DIR)."
    exit 1
fi
if [ ! -d "$DEST_DIR" ]; then
    echo "Error: El directorio de destino no existe ($DEST_DIR)."
    exit 1
fi

# Crear directorio de logs si no existe
mkdir -p "$LOG_DIR"

# Redirigir la salida tanto al archivo de log como a la consola
exec > >(tee "$LOG_FILE")
exec 2>&1

# Sincroniza los directorios con rsync sin borrar archivos en el destino
echo "Sincronizando $SOURCE_DIR a $DEST_DIR (sin borrar archivos en el destino)..."
rsync -av --progress --stats --delete "$SOURCE_DIR/" "$DEST_DIR/"

# Verifica si rsync falló
if [ $? -eq 0 ]; then
    echo "Sincronización completada con éxito."
else
    echo "Error: Falló la sincronización de los directorios."
    exit 1
fi