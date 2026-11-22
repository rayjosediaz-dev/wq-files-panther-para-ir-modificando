# Panther iOS + WQ Files — integración comprobable

## Estado real del código

Este repositorio se basa en Panther iOS original, preservando sus pantallas y motor de patches. No sustituye el proyecto por una interfaz simulada. Se examinó WQFiles-main.zip como referencia técnica, pero **no se integró ni se compiló su motor de acceso**: WQ Files es otra aplicación Objective-C con un método de acceso dependiente de la versión de iOS, y copiar su código sin adaptar su ciclo de vida, dependencias y permisos no produciría una integración fiable.

## Lo que ya trae Panther

- Menú de key y sesión en Keychain; `POST /v1/activate` con `key` y `device_id`.
- Token de sesión usado en `GET /v1/patches` y `GET /v1/patches/{id}/download`.
- Catálogo de patches online y actualización periódica de sesión.
- Motor de aplicación y restauración mediante `DevicePatchService` y `PatchTransaction`.
- Resolución de rutas de contenedores por bundle ID mediante `ContainerStore.resolveAppContainerPath`.

## Cambios de esta entrega

1. La compilación de GitHub Actions admite la variable de repositorio `PANTHER_API_BASE_URL` (HTTPS) y la escribe en Info.plist antes de compilar. Si no se define, conserva el valor del proyecto original.
2. El resolvedor de destino comprueba que el contenedor existe y es un directorio antes de aplicar o restaurar. No usa UUID de contenedor fijos.
3. Se conservan los archivos, recursos y pantallas del proyecto original.

## Configuración

GitHub → Settings → Secrets and variables → Actions → Variables → New repository variable: `PANTHER_API_BASE_URL` con la URL HTTPS real de tu servidor Panther, sin barra final. Subir el contenido del ZIP a un repositorio y ejecutar Actions → `Panther iOS - IPA sin firmar` → Run workflow. El artefacto resultante requiere firma válida para instalarse.

El backend debe implementar las rutas indicadas arriba, y devolver `token`, `expires_at` o `permanent` en la activación. El catálogo debe devolver un objeto con `patches` y cada patch debe tener `id` y `name`. La descarga debe devolver un archivo `.3105` válido.

## Limitaciones importantes

- No se verificó la compilación: este entorno no dispone de Xcode/iOS SDK.
- No se verificó la conexión con un servidor real ni se conoce su URL definitiva.
- En iOS sin permisos suficientes, no se puede garantizar el acceso a los contenedores de otras aplicaciones. WQ Files declara compatibilidad limitada por versión y el propio proyecto informa de versiones donde deja de funcionar.
- No se garantiza que un patch descargado pueda aplicarse a archivos de otra app. El motor informa del error cuando no puede resolver el destino.
- Solo deben modificarse archivos y aplicaciones sobre los que tengas autorización.
