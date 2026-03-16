# ⚙️ Manual de Administrador — Bodeguín
### Referencia técnica para mantenimiento y operación

---

## Stack del sistema

| Componente | Detalle |
|---|---|
| Orquestador | n8n 2.9.4 (self-hosted) |
| LLM | Google Gemini 2.5 Flash |
| Base de datos | Supabase (PostgreSQL) |
| Mensajería | Telegram Bot API |
| Infraestructura | Google Cloud Platform + EasyPanel |

---

## Agregar un nuevo usuario

1. Obtén el **Telegram ID** de la persona (puedes pedirle que te lo mande o usar [@userinfobot](https://t.me/userinfobot))
2. En Supabase → SQL Editor, ejecuta:

```sql
INSERT INTO usuarios (nom_usuario, telefono_wa, rol, telegram_id)
VALUES ('Nombre Apellido', '2221234567', 'Staff', 1234567890);
```

Roles disponibles: `'Voluntario'` · `'Staff'` · `'Administrador'`

---

## Cambiar el rol de un usuario

```sql
UPDATE usuarios
SET rol = 'Administrador'
WHERE nom_usuario = 'Nombre Apellido';
```

---

## Agregar artículos al catálogo

```sql
INSERT INTO articulos (nombre, descripcion)
VALUES ('Mazo de goma', 'Para golpear block sin dañarlo');
```

---

## Agregar una bodega (ubicación)

```sql
INSERT INTO ubicaciones (nombre_lugar, direccion)
VALUES ('Bodega Tepexco', 'Av. Principal 45, Tepexco');
```

---

## Cargar inventario inicial a una bodega

```sql
INSERT INTO inventario (id_articulo, id_ubicacion, estado, cantidad)
VALUES (1, 1, 'Bueno', 20);  -- 20 unidades del artículo 1 en ubicación 1
```

---

## Crear una construcción nueva

```sql
INSERT INTO construcciones (nombre, ubicacion, fecha_inicio)
VALUES ('Construcción 5VP Colonia X', 'Colonia X, Puebla', CURRENT_DATE);
```

---

## Crear cuadrillas para una construcción

```sql
-- Primero obtén el id de la construcción y el id del líder
INSERT INTO cuadrillas (id_construccion, nombre, id_lider)
VALUES (1, 'Cuadrilla 1', 5);  -- id_construccion=1, líder con id_usuario=5
```

---

## Cerrar una construcción terminada

Cuando termina el fin de semana de construcción y toda la herramienta fue regresada:

```sql
UPDATE construcciones
SET fecha_fin = CURRENT_DATE
WHERE nombre = 'Construcción 5VP Colonia X';
```

Esto hace que la construcción deje de aparecer en `vista_faltantes` automáticamente. Los datos se conservan para historial.

---

## Consultas útiles de mantenimiento

### Ver todas las construcciones activas
```sql
SELECT * FROM construcciones WHERE fecha_fin IS NULL;
```

### Ver herramienta sin regresar (global)
```sql
SELECT * FROM vista_faltantes ORDER BY construccion, cuadrilla;
```

### Ver inventario completo de una bodega
```sql
SELECT * FROM vista_inventario WHERE ubicacion = 'Bodega Central';
```

### Ver historial de asignaciones de una cuadrilla
```sql
SELECT ah.*, a.nombre AS articulo
FROM asignacion_herramienta ah
JOIN articulos a ON ah.id_articulo = a.id_articulo
WHERE ah.id_cuadrilla = 1;
```

### Encontrar el telegram_id de alguien por nombre
```sql
SELECT id_usuario, nom_usuario, rol, telegram_id
FROM usuarios
WHERE nom_usuario ILIKE '%nombre%';
```

---

## Arquitectura del workflow en n8n

```
Telegram Trigger
    │
    ├─ If (¿es mensaje de voz?)
    │       └─ Sí → Transcripción de audio
    │
    ▼
Edit Fields1 → Edit Fields2
(extrae mensaje y telegram_id)
    │
    ▼
Code in JavaScript1
(routing estático por keywords + memoria de última ruta por usuario)
    │
    ▼
Basic LLM Chain (clasificador Gemini)
→ Responde: "construye" o "bodega"
    │
    ├─ "bodega" → Agente Bodeguín
    │              Tools: articulos, ubicaciones, inventario, usuarios
    │              RPCs: pedir_material, regresar_material, regresar_todo_a_bodega
    │
    └─ "construye" → Agente Bodeguín Construye
                     Tools: articulos, usuarios, construcciones, cuadrillas,
                            asignacion_herramienta, vista_faltantes
                     RPCs: asignar_herramienta, regresar_herramienta_cuadrilla
    │
    ▼
Code: Limpieza de markdown + detección de señal [ENVIAR_MANUAL]
    │
    ├─ Si [ENVIAR_MANUAL] → Telegram: Send Document (PDF manual)
    │
    └─ Telegram: Send Message (respuesta de texto)
```

### Lógica de routing (Code in JavaScript1)

El nodo de JS detecta keywords antes de llamar al LLM clasificador para ahorrar latencia:

- **Keywords → construye:** `cuadrilla`, `construcción`, `asignar`, `faltantes`, `vivienda`, `regreso de herramienta`
- **Keywords → bodega:** `bodega`, `inventario`, `pedir material`, `regresar material`, `ubicacion`
- **Mensajes ambiguos** (`sí`, `confirmo`, `ok`, `dale`...): usa la última ruta guardada por `telegram_id` en static data de n8n

---

## Variables de entorno / credenciales en n8n

| Credencial | Nodo que la usa |
|---|---|
| `Telegram account` | Telegram Trigger, Enviar Mensaje, Mandar manual |
| `TCHO` (Supabase API) | Todos los nodos Supabase Tool |
| `Google Gemini` | Google Gemini Chat Model 1, 2 y 3 |

---

## Roadmap pendiente

- [ ] Migración de Telegram a WhatsApp (Evolution API)
- [ ] Dashboard web de inventario en tiempo real
- [ ] Notificaciones automáticas al detectar construcción sin herramienta regresada
- [ ] Soporte para fotos de herramienta dañada
- [ ] Reportes PDF por construcción al cerrarla
