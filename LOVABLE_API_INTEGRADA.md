# Panther iOS — API Lovable integrada

Servidor: https://panther-keygarden.lovable.app
Endpoints: POST /api/activate, POST /api/patches.
La app envía `key` y `device_id`, interpreta `role: user/admin` y `menus: patches/all`, y presenta errores documentados.
El catálogo admite `id`, `name`, `description`, `version`, `category`, `download_url`.
No se incluyen claves secretas en el ZIP. Las claves deben crearse desde el panel Lovable.
Pruebas pendientes: ejecutar IPA en iPhone y confirmar que los endpoints respondan; no se dispone de un entorno Xcode en este equipo.
Nota: la app usa identifierForVendor, que puede cambiar al desinstalar todas las apps del proveedor.
El catálogo es informativo y no instala parches remotamente.
