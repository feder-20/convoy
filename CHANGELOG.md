# Cambios

## 0.1.0 — Primera versión (MVP)
- Ventana de 852 × 712 con dos columnas, abierta desde el ícono de la barra de menú o con el atajo global ⌥⌘N (configurable). Pestañas **Nuevo proyecto** y **Plantillas** (⌘1 / ⌘2); Esc y ⌘W cierran; ↩ crea.
- Nuevo proyecto: nombre (con el foco al abrir), plantilla, «Crear en» (ruta por defecto, recientes y «Otra carpeta…»), casilla «Incluir el nombre del proyecto en cada carpeta» y vista previa en vivo con la ruta más larga. Tras crear: «Proyecto creado · N carpetas en…», «Mostrar en Finder» y «Crear otro».
- Convención de nombres para Windows, OneDrive y SharePoint: caracteres no válidos a guion, nombres reservados rechazados, puntos finales fuera, Unicode NFC, máximo 80 caracteres por segmento y presupuesto de ruta (aviso por encima de 200, bloqueo por encima de 400). Opción «Quitar tildes» en Ajustes (se conserva la ñ).
- Creación atómica: el árbol se arma en una carpeta temporal del mismo volumen y se mueve de una vez. Si la carpeta madre ya existe no se toca nada; si algo falla a mitad no queda nada en el destino. Nunca borra, mueve ni sobrescribe nada fuera de su carpeta temporal.
- Plantillas de fábrica (Proyecto, Campaña, Tecnología; no se editan, se duplican) y propias: crear, duplicar, renombrar, agregar, quitar, reordenar y subcarpetas de un nivel, con guardado automático. Exportar e importar archivos `.convoy` (JSON, con validación y mensajes claros); doble clic en un `.convoy` lo importa.
- Clic derecho en el Finder: Acción rápida «Nuevo proyecto con Convoy» (sobre una carpeta o el fondo de una ventana) que abre Convoy con esa carpeta como destino. Se instala desde Ajustes.
- Permisos: marcadores de seguridad para la ruta por defecto y los recientes; si falta permiso, se pide la carpeta con el panel del sistema.
- Español (base) e inglés completos, con prueba de cobertura. Sin red, sin cuentas, sin telemetría.
- 51 pruebas: dominio, casos de uso con dobles, adaptadores sobre carpetas reales (estructura completa, carpeta existente, fallo simulado y fallo real a mitad, falta de permiso), modelo de la interfaz y localización.
- Límites conocidos: la Acción rápida no ofrece submenú por plantilla (el sistema permite una acción por entrada); sin Finder Sync ni App Intent todavía; sin sandbox en esta entrega (el perfil de la App Store está preparado pero sin probar); sin probar en Windows ni en una carpeta de OneDrive.
