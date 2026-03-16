# 📱 Manual de Usuario — Bodeguín
### Para Staff y Voluntarios de TECHO Puebla

---

## ¿Qué es Bodeguín?

Bodeguín es un bot de Telegram que te ayuda a gestionar la herramienta de TECHO Puebla. Tiene dos modos:

- **Bodeguín** — para movimientos de bodega general (pedir y regresar material entre bodegas)
- **Bodeguín Construye** — para gestionar herramienta durante fines de semana de construcción

El bot te reconoce automáticamente por tu cuenta de Telegram. No necesitas escribir tu nombre ni contraseña.

---

## Cómo hablarle

Escríbele en lenguaje natural, como si fuera un compañero. No necesitas comandos exactos.

✅ **Así sí:**
```
¿Cuántos martillos hay en la bodega central?
Asigna 3 palas a la cuadrilla de Álvaro
¿Qué le falta regresar a la cuadrilla 2?
```

❌ **No necesitas:**
```
/inventario
/asignar id=3 cantidad=2
```

---

## Lo que puedes hacer según tu rol

| Acción | Voluntario | Staff | Administrador |
|---|:---:|:---:|:---:|
| Consultar inventario de bodega | ✅ | ✅ | ✅ |
| Consultar herramienta de cuadrilla | ✅ | ✅ | ✅ |
| Ver faltantes de construcción | ✅ | ✅ | ✅ |
| Pedir material de bodega | ❌ | ✅ | ✅ |
| Regresar material a bodega | ❌ | ✅ | ✅ |
| Asignar herramienta a cuadrilla | ❌ | ✅ | ✅ |
| Registrar regreso de herramienta | ❌ | ✅ | ✅ |
| Regresar todo a bodega | ❌ | ❌ | ✅ |

---

## Ejemplos de conversación

### Consultar inventario
```
Tú:       ¿Cuántas palas hay?
Bodeguín: Hay 8 palas en Bodega Central (estado: Bueno)
```

### Asignar herramienta a cuadrilla
```
Tú:                Asigna 2 mazos a la cuadrilla de Rodrigo
Bodeguín Construye: Voy a asignar:
                    - Artículo: Mazo
                    - Cantidad: 2
                    - Cuadrilla: Cuadrilla 3 (Líder: Rodrigo Hernández)
                    ¿Confirmas?
Tú:                Sí
Bodeguín Construye: ✅ Listo, 2 mazos asignados a la cuadrilla de Rodrigo.
```

### Ver qué le falta regresar a una cuadrilla
```
Tú:                ¿Qué tiene pendiente la cuadrilla de Ana?
Bodeguín Construye: La cuadrilla de Ana Flores tiene pendiente:
                    - 1 Nivel de burbuja
                    - 2 Llanas
```

### Pedir el manual constructivo
```
Tú:                ¿Cómo se instalan las cerchas?
Bodeguín Construye: Las cerchas se instalan sobre las paredes... [explicación]
                    [envía PDF del Manual Constructivo de TECHO]
```

---

## Consejos

- Si el bot no te reconoce, pide a un Administrador que registre tu Telegram ID en el sistema.
- Si el artículo que buscas no aparece, puede que el nombre sea diferente — intenta con sinónimos o pide ayuda a Staff.
- El bot recuerda el contexto de la conversación, así que puedes continuar sin repetir todo.

---

## ¿Algo no funciona?

Contacta a Luis Humberto Islas Guzmán, responsable del sistema.
