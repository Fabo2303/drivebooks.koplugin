# Drive Books para KOReader

Plugin experimental para explorar y descargar archivos desde una carpeta pública de Google Drive.

## Instalación

Copia la carpeta `drivebooks.koplugin` a:

`/mnt/us/koreader/plugins/drivebooks.koplugin/`

Reinicia KOReader. En el menú principal, busca **Drive Books**.

## Configuración

1. En Google Cloud Console, crea un proyecto.
2. Activa Google Drive API.
3. Crea una API Key y restríngela a Google Drive API.
4. En Drive Books, selecciona **Configurar API Key**.
5. La carpeta inicial ya está configurada con el ID proporcionado. Puedes cambiarlo en **Cambiar carpeta compartida**.
6. Selecciona **Probar conexión** y luego **Explorar libros de Drive**.

La carpeta y los archivos deben permitir acceso de lectura a cualquiera que tenga el enlace. Una API Key no concede acceso a archivos privados.

## Descargas

Los archivos se guardan en `/mnt/us/koreader/DriveBooks/`.

## Limitaciones de esta versión

- Prototipo no verificado en todas las versiones de KOReader.
- Requiere `ssl.https`, `ltn12`, `rapidjson` y `libs/libkoreader-lfs`.
- La interfaz lista archivos y permite entrar en subcarpetas; descarga un archivo por vez.
- No exporta documentos nativos de Google Docs, Sheets o Slides.
- No incluye barra de progreso ni reanudación de descargas.
- La API Key se guarda en el archivo de configuración de KOReader en texto plano.
- La descarga se ejecuta de forma síncrona y puede hacer que la interfaz parezca bloqueada durante archivos grandes.
- No sustituye a un plugin estable como Drivdle; úsalo primero con un archivo pequeño.

## Diagnóstico

Si el plugin no aparece, revisa el registro de KOReader y confirma que la carpeta se llame exactamente `drivebooks.koplugin`, no `drivebooks.koplugin/drivebooks.koplugin`.