# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Bodeguín** is a Telegram chatbot for intelligent tool/inventory management built for TECHO Puebla (a non-profit). It manages two domains:
- **Bodega (Warehouse)**: Material requests and returns from a physical storage
- **Construye (Construction)**: Tool assignments to work crews during weekend construction events

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Orchestration | n8n 2.9.4 (self-hosted workflow automation) |
| LLM/AI | Google Gemini 2.5 Flash |
| Database | Supabase (PostgreSQL) |
| Messaging | Telegram Bot API |
| Infrastructure | Google Cloud Platform + EasyPanel |

## Repository Structure

This is a **configuration-driven project** — there is no application code to compile or test framework to run.

- `database/schema.sql` — Full PostgreSQL DDL: 7 tables, 2 views, 5 stored procedures (RPCs)
- `workflows/bodeguin_workflow.json` — Complete n8n workflow export (import into n8n to deploy)
- `prompts/bodeguin_bodega.md` — System prompt for the Warehouse LLM agent
- `prompts/bodeguin_construye.md` — System prompt for the Construction LLM agent
- `docs/manual_usuario.md` — End-user guide (Staff/Volunteers)
- `docs/manual_admin.md` — Admin reference guide (includes initial SQL INSERT data)

## Deployment

1. Import `workflows/bodeguin_workflow.json` into n8n
2. Configure credentials in n8n UI: Telegram Bot Token, Supabase project URL + service key, Google Cloud API key
3. Execute `database/schema.sql` in the Supabase SQL editor
4. Seed initial data using the INSERT statements in `docs/manual_admin.md`
5. Activate the workflow in n8n (webhook is registered automatically)

## Architecture

### Request Flow

```
Telegram Message
  → (if voice) Transcription
  → Extract fields (message text, telegram_id)
  → Hybrid Router (keywords fast-path OR LLM classifier → "bodega" | "construye")
  → LLM Agent (Bodeguín Bodega OR Bodeguín Construye)
  → Markdown cleanup + [ENVIAR_MANUAL] detection
  → Send reply / PDF to Telegram
```

### LLM Agent Design

Both agents use **n8n Agent nodes** with Gemini 2.5 Flash and `Simple Memory` (keyed by `telegram_id` for conversational continuity). They have access to Supabase tools to query tables and call RPCs.

- **Routing**: A JavaScript node first checks keywords for common intents; ambiguous messages go to a Gemini classifier to reduce latency.
- **[ENVIAR_MANUAL] signal**: When the construction agent detects a construction topic, it appends `[ENVIAR_MANUAL]` to its response. A downstream JS node detects this and sends the PDF manual automatically.
- **Voice**: Audio messages are transcribed before entering the routing logic.

### Database Layer

Business logic lives in **PostgreSQL stored procedures (RPCs)**, not in the n8n workflow:

| RPC | Description |
|-----|-------------|
| `pedir_material(id_articulo, cantidad, id_usuario)` | Withdraw from warehouse (uses `FOR UPDATE` to prevent races) |
| `regresar_material(id_articulo, cantidad, id_usuario)` | Return to warehouse |
| `regresar_todo_a_bodega()` | Admin-only: consolidate all inventory back to warehouse |
| `asignar_herramienta(id_articulo, cantidad, id_cuadrilla)` | Assign tool to a crew |
| `regresar_herramienta_cuadrilla(id_articulo, cantidad, id_cuadrilla)` | Record crew tool return |

Key views: `vista_inventario` (stock with locations) and `vista_faltantes` (missing tools in active construction).

### Access Control

Role-based, enforced by the LLM agents querying the `usuarios` table by `telegram_id` (users are never asked for credentials):

| Role | Key Permissions |
|------|----------------|
| `voluntario` | Read-only queries |
| `staff` | + assign/return tools and materials |
| `administrador` | + `regresar_todo_a_bodega` |

## Modifying the System

- **Change agent behavior**: Edit the relevant file in `prompts/` and update the corresponding n8n Agent node's system prompt.
- **Change database schema**: Edit `database/schema.sql` and apply migrations manually in Supabase.
- **Change workflow logic**: Edit in the n8n UI, then export and overwrite `workflows/bodeguin_workflow.json`.
- **Credentials**: Never stored in this repo — managed entirely in n8n's credential store.
