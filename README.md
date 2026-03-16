# 🏗️ Bodeguín

> **Asistente inteligente de gestión de herramienta para TECHO Puebla**

[![n8n](https://img.shields.io/badge/n8n-2.9.4-orange?logo=n8n)](https://n8n.io)
[![Telegram](https://img.shields.io/badge/Telegram-Bot-blue?logo=telegram)](https://telegram.org)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?logo=supabase)](https://supabase.com)
[![Google Gemini](https://img.shields.io/badge/Google-Gemini_2.5_Flash-4285F4?logo=google)](https://deepmind.google/technologies/gemini/)
[![TECHO](https://img.shields.io/badge/TECHO-Puebla-red)](https://techo.org/mexico/)

---

## 📋 Descripción

**Bodeguín** es un sistema de bot de Telegram con inteligencia artificial que automatiza la gestión de herramienta de **TECHO Puebla**. Cubre dos flujos principales:

- **Bodeguín** — gestión de inventario general entre bodegas (pedir y regresar material)
- **Bodeguín Construye** — control de herramienta durante fines de semana de construcción de viviendas

El sistema está construido sobre **n8n** como orquestador de flujos, con agentes LLM (Google Gemini 2.5 Flash) que interpretan lenguaje natural y ejecutan operaciones directamente en Supabase vía RPCs de PostgreSQL. Los usuarios interactúan en lenguaje natural — el bot los identifica automáticamente por su `telegram_id`.

---

## ✨ Funcionalidades

| Función | Descripción | Roles |
|---|---|---|
| 📦 Consultar inventario | Stock por artículo, bodega y estado | Todos |
| 🔍 Ver herramienta de cuadrilla | Asignaciones activas por cuadrilla o líder | Todos |
| ⚠️ Ver faltantes | Herramienta sin regresar al cierre | Todos |
| ➕ Asignar herramienta | Registrar salida a cuadrilla | Staff / Admin |
| ↩️ Registrar regreso | Devolver herramienta de cuadrilla | Staff / Admin |
| 📤 Pedir material | Sacar material de bodega a encargado | Staff / Admin |
| 📥 Regresar material | Devolver material a bodega | Staff / Admin |
| 🏠 Regresar todo | Consolidar todo el inventario en bodega | Solo Admin |
| 📄 Manual constructivo | Enviar PDF del proceso constructivo TECHO | Todos |

---

## 🏛️ Arquitectura

```
Telegram (Usuario)
       │
       ▼
┌──────────────────────────────────────────────────┐
│                  n8n Workflow                    │
│                                                  │
│  Telegram Trigger                                │
│       │                                          │
│       ├─ If (¿voz?) → Transcripción             │
│       │                                          │
│       ▼                                          │
│  Edit Fields (mensaje + telegram_id)             │
│       │                                          │
│       ▼                                          │
│  Code JS — Routing por keywords                  │
│  + memoria de última ruta por usuario            │
│       │                                          │
│       ▼                                          │
│  Basic LLM Chain — Clasificador Gemini           │
│  → "bodega" | "construye"                        │
│       │                                          │
│   ┌───┴──────────────────────┐                   │
│   ▼                          ▼                   │
│ Agente Bodeguín     Agente Bodeguín Construye    │
│ (bodega general)    (construcción activa)        │
│   │                          │                   │
│   └──────────┬───────────────┘                   │
│              ▼                                   │
│   Code — Limpieza markdown                       │
│         + detección [ENVIAR_MANUAL]              │
│              │                                   │
│         ┌────┴────┐                              │
│         ▼         ▼                              │
│    Send Message  Send Document (PDF)             │
└──────────────────────────────────────────────────┘
       │
       ▼
Supabase (PostgreSQL)
Tablas: articulos, ubicaciones, inventario, usuarios,
        construcciones, cuadrillas, asignacion_herramienta
Vistas: vista_inventario, vista_faltantes
RPCs:   pedir_material, regresar_material, regresar_todo_a_bodega,
        asignar_herramienta, regresar_herramienta_cuadrilla
```

### Stack tecnológico

| Capa | Tecnología |
|---|---|
| Orquestación | n8n 2.9.4 |
| LLM | Google Gemini 2.5 Flash |
| Base de datos | Supabase (PostgreSQL) |
| Canal de mensajería | Telegram Bot API |
| Infraestructura | Google Cloud Platform + EasyPanel |

---

## 🗄️ Modelo de Base de Datos

```
articulos
├── id_articulo   SERIAL PK
├── nombre        VARCHAR NOT NULL
└── descripcion   VARCHAR

ubicaciones
├── id_ubicacion  SERIAL PK
├── nombre_lugar  VARCHAR NOT NULL
└── direccion     VARCHAR

usuarios
├── id_usuario    SERIAL PK
├── nom_usuario   VARCHAR NOT NULL
├── telefono_wa   VARCHAR NOT NULL
├── rol           VARCHAR DEFAULT 'Voluntario'
└── telegram_id   BIGINT UNIQUE

inventario
├── id_inventario SERIAL PK
├── id_articulo   FK → articulos
├── id_ubicacion  FK → ubicaciones
├── id_encargado  FK → usuarios (NULL = en bodega)
├── estado        VARCHAR DEFAULT 'Bueno'
└── cantidad      INTEGER DEFAULT 0

construcciones
├── id_construccion SERIAL PK
├── nombre          VARCHAR NOT NULL
├── ubicacion       VARCHAR NOT NULL
├── fecha_inicio    DATE NOT NULL
└── fecha_fin       DATE (NULL = activa)

cuadrillas
├── id_cuadrilla    SERIAL PK
├── id_construccion FK → construcciones
├── nombre          VARCHAR NOT NULL
└── id_lider        FK → usuarios

asignacion_herramienta
├── id_asignacion      SERIAL PK
├── id_cuadrilla       FK → cuadrillas
├── id_articulo        FK → articulos
├── cantidad_asignada  INTEGER NOT NULL
├── cantidad_regresada INTEGER (NULL = no regresado)
└── estado_regreso     VARCHAR (NULL | 'Completo' | 'Parcial')

── VISTAS ──
vista_inventario   → join articulos + ubicaciones + usuarios
vista_faltantes    → herramienta sin regresar en construcciones activas
```

### RPCs (Stored Procedures)

| RPC | Descripción | Parámetros clave |
|---|---|---|
| `pedir_material` | Saca material de bodega a encargado | id_articulo, id_ubicacion_origen, id_usuario, cantidad, estado |
| `regresar_material` | Devuelve material de encargado a bodega | id_articulo, id_ubicacion_destino, id_usuario, cantidad, estado |
| `regresar_todo_a_bodega` | Consolida todo el inventario (solo Admin) | p_id_bodega |
| `asignar_herramienta` | Registra salida de herramienta a cuadrilla | id_cuadrilla, id_articulo, cantidad_asignada |
| `regresar_herramienta_cuadrilla` | Registra regreso de cuadrilla | id_cuadrilla, id_articulo, cantidad_regresada, estado_regreso |

---

## 🔐 Sistema de Roles

| Rol | Permisos |
|---|---|
| **Voluntario** | Consultar inventario, cuadrillas y faltantes |
| **Staff** | Todo lo anterior + asignar/regresar herramienta y material |
| **Administrador** | Todo lo anterior + `regresar_todo_a_bodega`, cerrar construcciones |

La identificación es automática por `telegram_id`. Nunca se le pide al usuario su nombre.

---

## 🚀 Despliegue

### Requisitos
- n8n 2.9.4+ (self-hosted)
- Proyecto en Supabase (PostgreSQL)
- Google Cloud API Key (Gemini 2.5 Flash)
- Telegram Bot Token (obtenido desde [@BotFather](https://t.me/BotFather))

### Pasos

1. **Importar el workflow** en n8n → `workflows/bodeguin_workflow.json`
2. **Configurar credenciales** en n8n:
   - Telegram API → token del bot
   - Supabase API → URL + service role key
   - Google Gemini → API key
3. **Ejecutar el schema** en Supabase SQL Editor → `database/schema.sql`
4. **Cargar datos iniciales** → bodegas, artículos, inventario, usuarios con `telegram_id`
5. **Activar el workflow** en n8n
6. El webhook de Telegram se configura automáticamente al activar el nodo Trigger

---

## 💬 Ejemplos de uso

```
── BODEGA GENERAL ──────────────────────────────────

Usuario:  ¿Cuántas palas hay en la bodega central?
Bodeguín: Hay 12 palas en Bodega Central (estado: Bueno)

Usuario:  Quiero sacar 3 martillos para Tepexco
Bodeguín: Vas a sacar:
          - Artículo: Martillo
          - Cantidad: 3
          - Desde: Bodega Central → Tepexco
          ¿Confirmas?
Usuario:  Sí
Bodeguín: ✅ Listo, inventario actualizado.

── CONSTRUCCIÓN ────────────────────────────────────

Usuario:             Asigna 2 mazos a la cuadrilla de Álvaro
Bodeguín Construye:  Resumen:
                     - Artículo: Mazo
                     - Cantidad: 2
                     - Cuadrilla: Cuadrilla 1 (Líder: Álvaro Daumas)
                     ¿Confirmas?
Usuario:             Dale
Bodeguín Construye:  ✅ 2 mazos asignados a la cuadrilla de Álvaro.

Usuario:             ¿Cómo se instalan las cerchas?
Bodeguín Construye:  Las cerchas van sobre los muros... [explicación]
                     📄 [envía PDF del Manual Constructivo de TECHO]
```

---

## 📁 Estructura del repositorio

```
bodeguin/
├── README.md
├── workflows/
│   └── bodeguin_workflow.json      ← Workflow exportado de n8n
├── database/
│   └── schema.sql                  ← Tablas, vistas y RPCs
├── prompts/
│   ├── bodeguin_bodega.md          ← System prompt del agente de bodega
│   └── bodeguin_construye.md       ← System prompt del agente de construcción
└── docs/
    ├── manual_usuario.md           ← Guía para Staff y Voluntarios
    └── manual_admin.md             ← Guía de administración y mantenimiento
```

---

## 🗺️ Roadmap

- [x] Consultas de inventario por lenguaje natural
- [x] Asignación y regreso de herramienta (RPCs)
- [x] Validación de roles por telegram_id
- [x] Memoria conversacional por sesión
- [x] Routing inteligente (keywords + LLM clasificador)
- [x] Envío automático de PDF del manual constructivo
- [x] Vista de faltantes por cuadrilla
- [ ] Migración a WhatsApp (Evolution API)
- [ ] Dashboard web de inventario en tiempo real
- [ ] Notificaciones automáticas al cierre de construcción
- [ ] Soporte para fotos de herramienta dañada
- [ ] Reportes PDF por construcción al cerrarla

---

## 👤 Autor

Desarrollado por **Luis Humberto Islas Guzmán** para **TECHO Puebla** 🏠💙

---

## 📄 Licencia

Uso interno de TECHO Puebla. Para adaptación externa, contactar al autor.
