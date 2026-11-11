# Convoy — contexto del proyecto

> Documento de contexto para construir **Convoy** con Claude Code.
> Colócalo en la raíz del repositorio y pídele a Claude Code al iniciar cada sesión que lea `convoy.md`.
> Acompañan a este documento: `guia-visual/` (guía visual en HTML y PNG, y `design-tokens.json`) y `marca/` (kit de marca).
> Versión 1 · 11 de noviembre de 2026 · Responsable de producto: Federico Trujillo.

---

## 1. Qué es Convoy

Convoy es una mini app nativa de macOS, independiente, que **crea la estructura de carpetas de un proyecto en un clic**:

1. El usuario escribe el nombre del proyecto.
2. Elige una plantilla de carpetas (de fábrica o propia).
3. Elige dónde crearla (cualquier carpeta de Finder).
4. Convoy crea la **carpeta madre** con el nombre del proyecto y, dentro, todas las carpetas de la plantilla, numeradas y con el nombre del proyecto y el tipo de carpeta en cada una.

Convoy **solo crea carpetas vacías**. No crea archivos, no gestiona el proyecto, no sincroniza nada.

**Nombre:** Convoy, como un convoy de vehículos que avanzan juntos y en orden hacia un destino. Se escribe igual en español y en inglés.

### Ejemplo

Proyecto "Expansión Perú" con la plantilla "Proyecto", creado en `Documentos/Proyectos`:

```
Expansión Perú/
├── 01_Expansión Perú_Acta de constitucion/
├── 02_Expansión Perú_Stakeholders/
├── 03_Expansión Perú_Planeacion/
├── 04_Expansión Perú_Seguimiento/
│   ├── Actas de reunion/
│   └── Informes de avance/
├── 05_Expansión Perú_Costos/
│   ├── Cotizaciones/
│   └── Facturas/
├── 06_Expansión Perú_Contratos y proveedores/
├── 07_Expansión Perú_Entregables/
├── 08_Expansión Perú_Riesgos/
└── 09_Expansión Perú_Cierre/
```

### Público

Cualquier persona o área que arranca proyectos con frecuencia y quiere que todos queden organizados igual: gerentes y coordinadores de proyecto, PMO, TI, mercadeo, consultores y agencias. Interfaz en español primero, luego inglés.

---

## 2. Principios no negociables

1. **Simple.** Tres datos (nombre, plantilla, ruta) y un botón. Si una función complica ese flujo, no entra.
2. **Nunca destruir.** Convoy nunca borra, mueve ni sobrescribe archivos o carpetas existentes. Si la carpeta madre ya existe en la ruta, no crea nada y lo informa.
3. **Todo o nada.** La estructura se crea completa o no se crea; nunca quedan carpetas a medias.
4. **Compatible con Windows, OneDrive y SharePoint desde el origen.** Los nombres se validan antes de crear (sección 6).
5. **Local y privado.** Sin cuentas, sin servidores, sin telemetría por defecto, sin acceso a red.
6. **Nativo.** Swift y SwiftUI. Ligero, rápido, accesible con teclado y VoiceOver.
7. **Español primero.** Los textos se escriben en español (es-419); el inglés es traducción.

---

## 3. Alcance

### MVP

- Ícono en la barra de menú que abre la ventana de Convoy.
- Pestaña **Nuevo proyecto**: nombre, plantilla, ruta, opción "Incluir el nombre del proyecto en cada carpeta", vista previa en vivo y botón "Crear proyecto · N carpetas".
- Pestaña **Plantillas**: ver, agregar, quitar, renombrar y reordenar carpetas; agregar subcarpetas (un nivel); duplicar una plantilla; crear una plantilla nueva; eliminar plantillas propias.
- Tres plantillas de fábrica (sección 5), que no se pueden eliminar pero sí duplicar.
- Validación de nombres y rutas (sección 6).
- Creación atómica y botón "Mostrar en Finder".
- Rutas recientes y ruta por defecto recordadas.
- **Clic derecho en Finder**: "Nuevo proyecto con Convoy" › plantillas (sección 8.4).
- Exportar e importar plantillas como archivo `.convoy`.
- Localización es-419 (base) y en.

### Fuera de alcance

Archivos dentro de las carpetas, plantillas de Excel o Word, gestión de proyectos, registro o historial de proyectos, sincronización, cuentas, colaboración, versión para Windows.

### Fases siguientes (no construir ahora)

| Fase | Funciones |
| --- | --- |
| 2 | Crear plantilla a partir de una carpeta existente; subcarpetas de más de un nivel; arrastrar para reordenar y anidar; consecutivo opcional en el nombre de la carpeta madre (`PRY-2026-014`) |
| 3 | Carpeta de plantillas compartidas de la empresa (solo lectura); crear varios proyectos desde un CSV; acción para la app Atajos |

---

## 4. Experiencia de usuario

Referencia visual obligatoria: `guia-visual/convoy-guia-visual.html` (o su PNG). El prototipo interactivo del lienzo de diseño "Convoy · Mockups" muestra el comportamiento.

### 4.1 Pantallas

**Ventana principal** (852 × 712 pt, dos columnas, abierta desde la barra de menú):

- Barra superior: logo (símbolo + "convoy") a la izquierda; control segmentado "Nuevo proyecto | Plantillas" a la derecha.
- Columna izquierda, pestaña **Nuevo proyecto**:
  1. Campo "Nombre del proyecto" con el foco al abrir.
  2. Lista "Plantilla": una fila por plantilla con su nombre y el número de carpetas; la seleccionada con borde negro de 1,5 pt y fondo `#F4F4F4`.
  3. Menú "Crear en": ruta por defecto, recientes y "Otra carpeta…" (abre el panel de selección del sistema).
  4. Casilla "Incluir el nombre del proyecto en cada carpeta" (activada por defecto).
  5. Botón primario "Crear proyecto · N carpetas", deshabilitado si no hay nombre o la plantilla está vacía.
  6. Tras crear: confirmación "Proyecto creado · N carpetas en <ruta>" con "Mostrar en Finder" (primario) y "Crear otro".
- Columna izquierda, pestaña **Plantillas**:
  1. Selector de plantillas en pastillas y "+ Duplicar como nueva".
  2. Lista de carpetas: número, nombre editable, subir, bajar y quitar; subcarpetas indentadas con "+ Subcarpeta".
  3. Campo "Nueva carpeta" y botón "Agregar".
  4. Los cambios se guardan automáticamente.
- Columna derecha (ambas pestañas): **Vista previa** con la ruta de destino, el árbol con los nombres finales y la longitud de la ruta más larga.

### 4.2 Atajos de teclado

| Acción | Atajo |
| --- | --- |
| Abrir Convoy | Global, configurable (por defecto ⌥⌘N) |
| Crear proyecto | ↩ en la pestaña Nuevo proyecto |
| Cambiar de pestaña | ⌘1 y ⌘2 |
| Cerrar ventana | Esc o ⌘W |

### 4.3 Estados y textos

| Situación | Comportamiento | Texto |
| --- | --- | --- |
| Sin nombre | Botón deshabilitado; la vista previa muestra un marcador | "Nombre del proyecto" |
| Caracteres no válidos | Se reemplazan por guion y se avisa | "Se reemplazaron caracteres que Windows no permite." |
| Ruta larga | Aviso por encima de 200 caracteres; bloqueo por encima de 400 | "La ruta más larga tiene N caracteres. Algunas apps de Windows no abren archivos con rutas de más de 260." |
| Ya existe | No se crea nada; se ofrece abrir la existente | "Ya hay una carpeta llamada «X» aquí." |
| Sin permiso | Se pide acceso a la carpeta con el panel del sistema | "Convoy necesita permiso para crear carpetas en X." |
| Error al crear | Se revierte todo y se explica | "No se pudo crear el proyecto. No se cambió nada en X." |
| Éxito | Confirmación y acciones | "Proyecto creado · N carpetas en X" |

---

## 5. Plantillas de fábrica

Los nombres de tipo de carpeta de fábrica van sin tildes para maximizar la compatibilidad; el nombre del proyecto conserva las tildes que escriba el usuario.

| Plantilla | Carpetas (en orden) | Subcarpetas |
| --- | --- | --- |
| **Proyecto** (por defecto) | Acta de constitucion, Stakeholders, Planeacion, Seguimiento, Costos, Contratos y proveedores, Entregables, Riesgos, Cierre | Seguimiento: Actas de reunion, Informes de avance · Costos: Cotizaciones, Facturas |
| **Campaña** | Brief, Stakeholders, Creatividad, Piezas, Pauta, Seguimiento, Costos, Resultados | Piezas: Aprobadas, En revision |
| **Tecnología** | Acta de constitucion, Stakeholders, Requisitos, Arquitectura, Desarrollo, Pruebas, Seguimiento, Costos, Despliegue, Cierre | Seguimiento: Actas de reunion, Informes de avance |

---

## 6. Convención de nombres y validación

### 6.1 Patrones

| Elemento | Con "Incluir el nombre del proyecto" | Sin esa opción |
| --- | --- | --- |
| Carpeta madre | `{proyecto}` | `{proyecto}` |
| Carpeta de primer nivel | `{nn}_{proyecto}_{tipo}` | `{nn}_{tipo}` |
| Subcarpeta | `{tipo}` | `{tipo}` |

- `{nn}`: número de orden con dos dígitos (`01`…`99`), según el orden de la plantilla.
- `{proyecto}`: nombre escrito por el usuario, ya saneado.
- `{tipo}`: nombre de la carpeta en la plantilla.
- Separador: guion bajo `_`.

### 6.2 Reglas (se aplican en este orden, antes de tocar el disco)

1. Recortar espacios al inicio y al final; reducir espacios múltiples a uno.
2. Reemplazar por guion los caracteres no válidos en Windows, OneDrive y SharePoint: `" * : < > ? / \ |` y caracteres de control.
3. Quitar puntos al final del nombre.
4. Rechazar nombres reservados: `CON`, `PRN`, `AUX`, `NUL`, `COM0`–`COM9`, `LPT0`–`LPT9`, `.lock`, `desktop.ini`, nombres que empiezan por `~$` o contienen `_vti_`.
5. Normalizar a Unicode **NFC** para que las tildes y la ñ se vean igual en Windows.
6. Opción en Ajustes "Quitar tildes" (desactivada por defecto): "Expansión" → "Expansion".
7. Máximo 80 caracteres por segmento.
8. Calcular la ruta completa más larga del árbol resultante: advertir por encima de 200 caracteres y bloquear por encima de 400.
9. Verificar que la carpeta madre no exista en la ruta de destino.

Referencias: límites de ruta de OneDrive, SharePoint y Office ([Microsoft](https://support.microsoft.com/en-us/onedrive/what-are-file-path-length-limits)); caracteres y nombres no permitidos ([Microsoft](https://support.microsoft.com/en-us/help/3125202)).

---

## 7. Modelo de datos y formato de plantilla

### 7.1 Dominio

```swift
struct FolderNode: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var children: [FolderNode]          // MVP: un nivel
}

struct Template: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var isBuiltIn: Bool
    var folders: [FolderNode]
    var schemaVersion: Int = 1
}

struct ProjectRequest: Sendable {
    var projectName: String
    var template: Template
    var destination: URL
    var includeProjectNameInFolders: Bool
}

struct PlannedFolder: Sendable, Hashable {
    let relativePath: [String]          // segmentos desde la carpeta madre
}

struct CreationPlan: Sendable {
    let rootName: String
    let folders: [PlannedFolder]
    let longestPathLength: Int
    let warnings: [NamingWarning]
    var folderCount: Int { folders.count }
}

enum NamingWarning: Sendable, Equatable { case replacedCharacters, longPath(Int) }

enum ConvoyError: Error, Equatable {
    case emptyName, emptyTemplate, reservedName(String)
    case pathTooLong(Int), alreadyExists(String)
    case noPermission(URL), creationFailed(String)
}
```

### 7.2 Archivo de plantilla `.convoy`

JSON con extensión `.convoy` (UTType propio `co.convoy.template`, conforme a `public.json`). Sirve para exportar, importar y compartir.

```json
{
  "schemaVersion": 1,
  "name": "Proyecto",
  "folders": [
    { "name": "Acta de constitucion" },
    { "name": "Stakeholders" },
    { "name": "Planeacion" },
    { "name": "Seguimiento", "children": [{ "name": "Actas de reunion" }, { "name": "Informes de avance" }] },
    { "name": "Costos", "children": [{ "name": "Cotizaciones" }, { "name": "Facturas" }] },
    { "name": "Contratos y proveedores" },
    { "name": "Entregables" },
    { "name": "Riesgos" },
    { "name": "Cierre" }
  ]
}
```

### 7.3 Persistencia

- Plantillas propias y preferencias en el contenedor de la app: `Application Support/Convoy/templates/*.convoy` (un archivo por plantilla, legible y fácil de respaldar).
- Plantillas de fábrica empaquetadas en el bundle (`Resources/BuiltInTemplates/`).
- Ruta por defecto y recientes como *security-scoped bookmarks* en `UserDefaults`.

---

## 8. Arquitectura

### 8.1 Decisiones

| Tema | Decisión |
| --- | --- |
| Lenguaje | Swift 6, concurrencia estricta |
| Interfaz | SwiftUI; `MenuBarExtra` con estilo `.window`; AppKit solo donde haga falta |
| Versión mínima | macOS 14 Sonoma (a confirmar) |
| Arquitectura | Hexagonal: dominio puro, casos de uso, puertos y adaptadores |
| Persistencia | Archivos JSON `.convoy` + `UserDefaults`; sin base de datos |
| Distribución | Mac App Store (sandbox) y venta directa notarizada (decisión pendiente) |
| Dependencias externas | Ninguna en el MVP |

### 8.2 Capas

```
Presentation  →  Application (casos de uso)  →  Domain
                         │
                         └→ Ports (protocolos) ← Adapters
```

| Capa | Contenido |
| --- | --- |
| Domain | `FolderNode`, `Template`, `ProjectRequest`, `CreationPlan`, `NameSanitizer`, `PathBudget`, `ConvoyError` (sin importar AppKit ni FileManager) |
| Application | `PlanProject` (genera el plan y las advertencias), `CreateProject` (ejecuta el plan), `ManageTemplates` (crear, duplicar, editar, eliminar, importar, exportar) |
| Ports | `FolderWriter`, `TemplateRepository`, `LocationAccess`, `FinderRevealer` |
| Adapters | `FileManagerFolderWriter`, `JSONTemplateRepository`, `BookmarkLocationAccess`, `NSWorkspaceRevealer` |
| Presentation | `MenuBarExtra`, `NewProjectView`, `TemplatesView`, `PreviewTreeView`, view models con `@Observable` |

```swift
protocol FolderWriter: Sendable {
    func exists(_ name: String, in parent: URL) throws -> Bool
    func create(_ plan: CreationPlan, in parent: URL) async throws -> URL   // atómico
}
protocol TemplateRepository: Sendable {
    func all() throws -> [Template]
    func save(_ template: Template) throws
    func delete(id: UUID) throws
    func importFile(at url: URL) throws -> Template
    func export(_ template: Template, to url: URL) throws
}
protocol LocationAccess: Sendable {
    func withAccess<T>(to url: URL, _ body: () throws -> T) throws -> T
    func remember(_ url: URL) throws
    func recent() -> [URL]
}
```

### 8.3 Creación atómica

1. `PlanProject` valida y produce el `CreationPlan`. Si hay error, no se toca el disco.
2. Comprobar que la carpeta madre no exista en el destino.
3. Crear todo el árbol en una carpeta temporal **del mismo volumen** que el destino: `FileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: destino, create: true)`.
4. Mover la carpeta madre completa al destino con `moveItem` (operación atómica dentro del mismo volumen).
5. Si cualquier paso falla, eliminar solo la carpeta temporal creada por Convoy y devolver `creationFailed`. Nunca tocar nada fuera de esa carpeta temporal.
6. Revelar el resultado en Finder si el usuario lo pide.

### 8.4 Clic derecho en Finder

- Opción principal: **extensión Finder Sync** que agrega "Nuevo proyecto con Convoy" con un submenú por plantilla en las carpetas donde el usuario dio permiso (sus rutas recientes y la ruta por defecto). Al elegir una plantilla, abre la ventana de Convoy con la plantilla y la ruta ya fijadas y el foco en el nombre.
- Alternativa si la extensión no es viable en la App Store: un **App Intent** "Crear proyecto con Convoy" que el usuario agrega como Acción rápida de Finder desde la app Atajos.
- Validar ambas opciones al inicio del desarrollo (decisión pendiente).

### 8.5 Sandbox y permisos

- `com.apple.security.app-sandbox` y `com.apple.security.files.user-selected.read-write`.
- `com.apple.security.files.bookmarks.app-scope` para recordar carpetas.
- Sin derechos de red.
- Hardened runtime, firma Developer ID y notarización para la venta directa.

---

## 9. Marca y diseño

- Kit en `marca/`: ícono de app (PNG 1024 para AppIcon), símbolo negro y blanco sobre transparente, ícono de barra de menú como **Template Image** (`convoy-barra-menu-template.svg`, PNG 18 y 36 px) y logos horizontales.
- Símbolo: carpeta con tres líneas escalonadas recortadas.
- Colores, tipografía, radios, sombras y tamaños: `guia-visual/design-tokens.json`.
- Solo blanco, negro y grises. Sin color de acento. En modo oscuro, colores semánticos del sistema.
- En la app, fuente del sistema (SF Pro); Inter solo en el logo.

---

## 10. Estructura del repositorio

```
Convoy/
├── convoy.md
├── guia-visual/                 # Guía visual y tokens (referencia, no se compila)
├── marca/                       # Kit de marca
├── Convoy.xcodeproj
├── App/                         # ConvoyApp, MenuBarExtra, composición de dependencias
├── Presentation/
│   ├── NewProject/
│   ├── Templates/
│   ├── Preview/
│   └── DesignSystem/            # Colores, tipografía y componentes según design-tokens.json
├── Application/                 # PlanProject, CreateProject, ManageTemplates
├── Domain/                      # Modelos, NameSanitizer, PathBudget, errores
├── Ports/
├── Adapters/
├── Extensions/
│   ├── FinderSync/
│   └── Intents/
├── Resources/
│   ├── BuiltInTemplates/        # proyecto.convoy, campana.convoy, tecnologia.convoy
│   ├── Assets.xcassets          # AppIcon e ícono de barra de menú
│   └── Localizable.xcstrings    # es-419 base, en
└── Tests/
    ├── DomainTests/
    ├── ApplicationTests/
    ├── AdapterTests/
    └── UITests/
```

---

## 11. Pruebas

- **Dominio (unitarias):**
  - `NameSanitizer`: cada carácter prohibido, nombres reservados, espacios, puntos finales, NFC con "é" y "ñ" escritas en NFD, opción de quitar tildes.
  - `PathBudget`: aviso a 201 caracteres, bloqueo a 401.
  - `PlanProject`: numeración `01`…`10`, con y sin nombre del proyecto, subcarpetas, plantilla vacía.
- **Adaptadores (integración, en carpetas temporales):**
  - Crear la estructura completa y comparar con la esperada.
  - Carpeta madre existente: no se crea nada.
  - Fallo simulado a mitad de la creación: no queda nada en el destino.
  - Importar y exportar `.convoy`, incluido un archivo inválido.
- **UI:** flujo completo de crear proyecto; editar plantilla y ver la vista previa actualizada; navegación con teclado; VoiceOver en los controles principales.
- **Compatibilidad:** abrir en Windows 11 y en una carpeta sincronizada con OneDrive una estructura con tildes y ñ, y verificar nombres.

---

## 12. Criterios de aceptación del MVP

1. Desde la barra de menú, crear un proyecto toma tres datos y un clic.
2. La vista previa coincide exactamente con lo que se crea en disco.
3. Las carpetas se crean numeradas y, con la opción activa, con el nombre del proyecto y el tipo.
4. Ningún nombre creado contiene caracteres o nombres no permitidos por Windows, OneDrive o SharePoint.
5. Si la carpeta madre existe, no se crea ni se modifica nada.
6. Si la creación falla a mitad, no queda ninguna carpeta en el destino.
7. Las plantillas propias se pueden crear, duplicar, editar, eliminar, exportar e importar, y sobreviven al reinicio.
8. "Nuevo proyecto con Convoy" funciona desde el clic derecho de Finder (o, en su defecto, como Acción rápida).
9. La app no hace llamadas de red.
10. Toda la interfaz está en español e inglés.

---

## 13. Backlog inicial

1. Proyecto Xcode con las capas de la sección 10 y el design system desde `design-tokens.json`.
2. Dominio: modelos, `NameSanitizer`, `PathBudget` y sus pruebas.
3. `PlanProject` y vista previa en vivo.
4. `JSONTemplateRepository` y plantillas de fábrica.
5. `FileManagerFolderWriter` con creación atómica y sus pruebas.
6. Pestaña Nuevo proyecto completa.
7. Pestaña Plantillas completa.
8. Permisos de carpeta, ruta por defecto y recientes.
9. Exportar e importar `.convoy`.
10. Extensión Finder Sync (o App Intent como alternativa).
11. Ícono de app y de barra de menú; localización es-419 y en.
12. Firma, notarización y empaquetado.

---

## 14. Decisiones pendientes

- [ ] Verificar la marca "Convoy" (SIC, USPTO, EUIPO), el dominio y el nombre en la App Store.
- [ ] Canal de distribución: Mac App Store, venta directa o ambos.
- [ ] Precio: gratis, pago único o versión gratuita con funciones Pro.
- [ ] Versión mínima de macOS.
- [ ] Finder Sync frente a App Intent para el clic derecho.

---

## 15. Instrucciones para Claude Code

- Responde y documenta en **español**; tipos, funciones y variables en **inglés**.
- Respeta la regla de dependencias: el dominio no importa AppKit, SwiftUI ni FileManager.
- Sigue la guía visual y los tokens; no inventes colores ni estilos fuera de ellos.
- Nunca escribas código que borre, mueva o sobrescriba algo fuera de la carpeta temporal que Convoy crea.
- No agregues dependencias externas sin preguntar.
- No agregues llamadas de red.
- Toda función nueva necesita pruebas y textos en `Localizable.xcstrings`.
- Ejecuta las pruebas antes de dar una tarea por terminada.
- Mensajes de commit en español, en imperativo y cortos ("Agrega validación de nombres reservados").
- Si una decisión de la sección 14 bloquea el trabajo, presenta opciones con pros y contras y pregunta.
