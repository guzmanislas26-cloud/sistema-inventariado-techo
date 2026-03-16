# 🏗️ Bodeguín

> **AI-powered tool & inventory management assistant for TECHO Puebla**

[![n8n](https://img.shields.io/badge/n8n-2.9.4-orange?logo=n8n)](https://n8n.io)
[![Telegram](https://img.shields.io/badge/Telegram-Bot-blue?logo=telegram)](https://telegram.org)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?logo=supabase)](https://supabase.com)
[![Google Gemini](https://img.shields.io/badge/Google-Gemini_2.5_Flash-4285F4?logo=google)](https://deepmind.google/technologies/gemini/)
[![TECHO](https://img.shields.io/badge/TECHO-Puebla-red)](https://techo.org/mexico/)

🌐 [English](#english) · [Español](#español)

---

<a name="english"></a>
## 📋 Description

**Bodeguín** is a Telegram chatbot with AI that automates tool and inventory management for **TECHO Puebla**, a non-profit that builds emergency housing. It covers two main workflows:

- **Bodeguín** — general warehouse inventory management (requesting and returning materials)
- **Bodeguín Construye** — tool tracking during weekend housing construction events

The system is built on **n8n** as the workflow orchestrator, with LLM agents (Google Gemini 2.5 Flash) that interpret natural language and execute operations directly in Supabase via PostgreSQL RPCs. Users interact in plain language — the bot identifies them automatically by their `telegram_id`.

---

## ✨ Features

| Feature | Description | Roles |
|---|---|---|
| 📦 Query inventory | Stock by item, warehouse, and condition | All |
| 🔍 View crew tools | Active assignments by crew or leader | All |
| ⚠️ View missing items | Unreturned tools at end of event | All |
| ➕ Assign tool | Log tool checkout to a crew | Staff / Admin |
| ↩️ Record return | Log tool return from a crew | Staff / Admin |
| 📤 Request material | Check out material from warehouse | Staff / Admin |
| 📥 Return material | Return material to warehouse | Staff / Admin |
| 🏠 Return all | Consolidate all inventory to warehouse | Admin only |
| 📄 Construction manual | Send the TECHO construction PDF guide | All |

---

## 🏛️ Architecture

```
Telegram (User)
       │
       ▼
┌──────────────────────────────────────────────────┐
│                  n8n Workflow                    │
│                                                  │
│  Telegram Trigger                                │
│       │                                          │
│       ├─ If (voice?) → Transcription             │
│       │                                          │
│       ▼                                          │
│  Edit Fields (message + telegram_id)             │
│       │                                          │
│       ▼                                          │
│  JS Code — Keyword router                        │
│  + last-route memory per user                    │
│       │                                          │
│       ▼                                          │
│  Basic LLM Chain — Gemini Classifier             │
│  → "bodega" | "construye"                        │
│       │                                          │
│   ┌───┴──────────────────────┐                   │
│   ▼                          ▼                   │
│ Bodeguín Agent      Bodeguín Construye Agent     │
│ (general warehouse) (active construction)        │
│   │                          │                   │
│   └──────────┬───────────────┘                   │
│              ▼                                   │
│   Code — Markdown cleanup                        │
│         + [ENVIAR_MANUAL] detection              │
│              │                                   │
│         ┌────┴────┐                              │
│         ▼         ▼                              │
│    Send Message  Send Document (PDF)             │
└──────────────────────────────────────────────────┘
       │
       ▼
Supabase (PostgreSQL)
Tables: articulos, ubicaciones, inventario, usuarios,
        construcciones, cuadrillas, asignacion_herramienta
Views:  vista_inventario, vista_faltantes
RPCs:   pedir_material, regresar_material, regresar_todo_a_bodega,
        asignar_herramienta, regresar_herramienta_cuadrilla
```

### Tech Stack

| Layer | Technology |
|---|---|
| Orchestration | n8n 2.9.4 |
| LLM | Google Gemini 2.5 Flash |
| Database | Supabase (PostgreSQL) |
| Messaging | Telegram Bot API |
| Infrastructure | Google Cloud Platform + EasyPanel |

---

## 🗄️ Database Model

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
├── id_encargado  FK → usuarios (NULL = in warehouse)
├── estado        VARCHAR DEFAULT 'Bueno'
└── cantidad      INTEGER DEFAULT 0

construcciones
├── id_construccion SERIAL PK
├── nombre          VARCHAR NOT NULL
├── ubicacion       VARCHAR NOT NULL
├── fecha_inicio    DATE NOT NULL
└── fecha_fin       DATE (NULL = active)

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
├── cantidad_regresada INTEGER (NULL = not returned)
└── estado_regreso     VARCHAR (NULL | 'Completo' | 'Parcial')

── VIEWS ──
vista_inventario   → join articulos + ubicaciones + usuarios
vista_faltantes    → unreturned tools in active constructions
```

### RPCs (Stored Procedures)

| RPC | Description | Key Parameters |
|---|---|---|
| `pedir_material` | Check out material from warehouse | id_articulo, id_ubicacion_origen, id_usuario, cantidad, estado |
| `regresar_material` | Return material to warehouse | id_articulo, id_ubicacion_destino, id_usuario, cantidad, estado |
| `regresar_todo_a_bodega` | Consolidate all inventory (Admin only) | p_id_bodega |
| `asignar_herramienta` | Log tool checkout to crew | id_cuadrilla, id_articulo, cantidad_asignada |
| `regresar_herramienta_cuadrilla` | Log crew tool return | id_cuadrilla, id_articulo, cantidad_regresada, estado_regreso |

---

## 🔐 Role System

| Role | Permissions |
|---|---|
| **Voluntario** | Query inventory, crews, and missing items |
| **Staff** | All of the above + assign/return tools and materials |
| **Administrador** | All of the above + `regresar_todo_a_bodega`, close constructions |

Identification is automatic via `telegram_id` — users are never asked for their name.

---

## 🚀 Deployment

### Requirements
- n8n 2.9.4+ (self-hosted)
- Supabase project (PostgreSQL)
- Google Cloud API Key (Gemini 2.5 Flash)
- Telegram Bot Token (from [@BotFather](https://t.me/BotFather))

### Steps

1. **Import the workflow** into n8n → `workflows/bodeguin_workflow.json`
2. **Configure credentials** in n8n:
   - Telegram API → bot token
   - Supabase API → project URL + service role key
   - Google Gemini → API key
3. **Run the schema** in Supabase SQL Editor → `database/schema.sql`
4. **Seed initial data** → warehouses, items, inventory, users with `telegram_id`
5. **Activate the workflow** in n8n
6. The Telegram webhook is configured automatically when the Trigger node activates

---

## 💬 Usage Examples

```
── GENERAL WAREHOUSE ───────────────────────────────
User:     How many shovels are in the central warehouse?
Bodeguín: There are 12 shovels in Bodega Central (condition: Good)

User:     I need to check out 3 hammers for Tepexco
Bodeguín: You're checking out:
          - Item: Hammer
          - Quantity: 3
          - From: Bodega Central → Tepexco
          Confirm?
User:     Yes
Bodeguín: ✅ Done, inventory updated.

── CONSTRUCTION ─────────────────────────────────────
User:                   Assign 2 mallets to Álvaro's crew
Bodeguín Construye:     Summary:
                        - Item: Mallet
                        - Quantity: 2
                        - Crew: Crew 1 (Leader: Álvaro Daumas)
                        Confirm?
User:                   Go ahead
Bodeguín Construye:     ✅ 2 mallets assigned to Álvaro's crew.

User:                   How are the trusses installed?
Bodeguín Construye:     Trusses go on top of the walls... [explanation]
                        📄 [sends TECHO Construction Manual PDF]
```

---

## 📁 Repository Structure

```
bodeguin/
├── README.md
├── workflows/
│   └── bodeguin_workflow.json      ← Exported n8n workflow
├── database/
│   └── schema.sql                  ← Tables, views, and RPCs
├── prompts/
│   ├── bodeguin_bodega.md          ← Warehouse agent system prompt
│   └── bodeguin_construye.md       ← Construction agent system prompt
└── docs/
    ├── manual_usuario.md           ← Guide for Staff and Volunteers
    └── manual_admin.md             ← Administration and maintenance guide
```

---

## 🗺️ Roadmap

- [x] Natural language inventory queries
- [x] Tool assignment and return (RPCs)
- [x] Role validation via telegram_id
- [x] Conversational memory per session
- [x] Intelligent routing (keywords + LLM classifier)
- [x] Automatic PDF delivery of construction manual
- [x] Missing items view by crew
- [ ] Migration to WhatsApp (Evolution API)
- [ ] Real-time web inventory dashboard
- [ ] Automatic notifications at construction close
- [ ] Support for photos of damaged tools
- [ ] PDF reports per construction event on close

---

## 👤 Author

Developed by **Luis Humberto Islas Guzmán** for **TECHO Puebla** 🏠💙

---

## 📄 License

Internal use for TECHO Puebla. For external adaptation, contact the author.

---
---

<a name="español"></a>
# 🏗️ Bodeguín *(Español)*

> **Asistente inteligente de gestión de herramienta para TECHO Puebla**

🌐 [English](#english) · [Español](#español)

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
