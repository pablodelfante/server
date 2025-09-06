#!/bin/bash
# Script para verificar la salud de discos
# Uso: ./storage_health.sh [dispositivo]

# Obtener el directorio donde está el script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/server_logs/disk_health"
LOG_FILE="$LOG_DIR/disk_health_$(date +%Y%m%d_%H%M%S).log"

# Función para verificar e instalar smartctl
check_smartctl() {
    if ! command -v smartctl &> /dev/null; then
        echo "smartctl no está instalado. Instalando smartmontools..."
        
        # Detectar distribución y instalar
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y smartmontools
        elif command -v yum &> /dev/null; then
            sudo yum install -y smartmontools
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm smartmontools
        else
            echo "No se pudo detectar el gestor de paquetes. Instala smartmontools manualmente."
            return 1
        fi
        
        # Verificar instalación
        if command -v smartctl &> /dev/null; then
            echo "smartctl instalado correctamente."
            return 0
        else
            echo "Error: No se pudo instalar smartctl."
            return 1
        fi
    else
        echo "smartctl ya está instalado."
        return 0
    fi
}

# Función para verificar salud de un disco específico
check_disk_health() {
    local disk="$1"
    
    if [ ! -b "$disk" ]; then
        echo "❌ Error: $disk no es un dispositivo de bloque válido."
        return 1
    fi
    
    echo "🔍 Verificando salud del disco: $disk"
    echo "----------------------------------------"
    
    # Verificar si el disco soporta SMART
    if ! smartctl -i "$disk" | grep -q "SMART support is: Available"; then
        echo "⚠️ $disk: SMART no está disponible"
        return 1
    fi
    
    # Verificar estado general de salud
    local health_status=$(smartctl -H "$disk" | grep "SMART overall-health self-assessment test result:")
    echo "$health_status"
    
    if echo "$health_status" | grep -q "PASSED"; then
        echo "✅ $disk: SALUDABLE"
        
        # Mostrar información adicional
        echo ""
        echo "📊 Información del disco:"
        smartctl -i "$disk" | grep -E "(Model|Serial|Capacity|Power_On_Hours)"
        
        return 0
    else
        echo "❌ $disk: PROBLEMAS DETECTADOS"
        
        # Mostrar errores específicos
        echo ""
        echo "�� Errores detectados:"
        smartctl -l error "$disk"
        
        return 1
    fi
}

# Función para listar todos los discos disponibles
list_disks() {
    echo "💾 Discos disponibles en el sistema:"
    echo "-----------------------------------"
    lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT | grep disk
    echo ""
}

# Función principal
main() {
    # Crear directorio de logs si no existe
    mkdir -p "$LOG_DIR"
    
    # Redirigir la salida tanto al archivo de log como a la consola
    exec > >(tee "$LOG_FILE")
    exec 2>&1
    
    echo "🔧 Verificador de Salud de Discos"
    echo "=================================="
    echo "Log guardado en: $LOG_FILE"
    echo ""
    
    # Verificar e instalar smartctl
    if ! check_smartctl; then
        echo "No se puede continuar sin smartctl."
        exit 1
    fi
    
    echo ""
    
    # Si se proporciona un dispositivo específico
    if [ $# -eq 1 ]; then
        check_disk_health "$1"
    else
        # Listar discos disponibles
        list_disks
        
        # Verificar todos los discos SATA/SCSI
        echo "🔍 Verificando salud de todos los discos..."
        echo ""
        
        local all_healthy=true
        
        for disk in /dev/sd[a-z]; do
            if [ -b "$disk" ]; then
                if ! check_disk_health "$disk"; then
                    all_healthy=false
                fi
                echo ""
            fi
        done
        
        # Resumen final
        echo "=================================="
        if [ "$all_healthy" = true ]; then
            echo "✅ RESUMEN: Todos los discos están saludables"
            exit 0
        else
            echo "❌ RESUMEN: Se detectaron problemas en uno o más discos"
            exit 1
        fi
    fi
}

# Ejecutar función principal
main "$@"