"""Convierte la respuesta de /accounts/sincronizar en un informe legible.

Vive aparte del workflow porque embebido en el YAML habia que escapar cada
comilla, y un informe que nadie puede leer no sirve de mucho.

Sale con codigo 1 si alguna cuenta fallo: sin eso, un token con la IP mal
dejaria fallar todas las sincronizaciones dia tras dia y el workflow seguiria
en verde.
"""

import json
import sys

datos = json.load(sys.stdin)
cuentas = datos.get("cuentas", [])
fallaron = [c for c in cuentas if not c["ok"]]
cambiadas = [c for c in cuentas if c["ok"] and c["resumen"]["actualizados"] > 0]

print(f"{len(cuentas)} cuentas con tag")

for cuenta in cambiadas:
    print(f"  {cuenta['nombre']}: +{cuenta['resumen']['actualizados']} elementos")

if not cambiadas and not fallaron:
    print("  ya estaban todas al dia")

for cuenta in fallaron:
    print(f"  FALLO {cuenta['nombre']}: {cuenta['error']}")

sys.exit(1 if fallaron else 0)
