# Aviso de vencimiento en Panther iOS

Se programa una notificación local para cada key no permanente, 24 horas antes del vencimiento indicado por el servidor. Al renovar o revalidar, se reprograma; al cerrar sesión, se cancela. Si ya quedan menos de 24 horas, se programa para mostrarse pronto. Requiere permiso de notificaciones y una instalación actualizada de Panther iOS. Imagen PantherLaunch adjunta a la notificación ampliada. No es una notificación push remota y no se puede forzar un fondo de imagen en el banner compacto de iOS. No probado en Xcode/iPhone en este entorno.
