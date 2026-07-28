#!/bin/bash
# Genera el EPUB español desde book.org.
#
#     ./build_es_epub.sh   ->  crecer_en_libertad.epub
#
# POR QUÉ EXISTE
# En el repo había una carpeta "Crecer en Libertad.epub" con una
# exportación vieja de Leanpub: 49.983 palabras de un borrador distinto,
# sin ninguna de las escenas de Arjuna y Nitai. No es este libro. No se
# vende eso.
#
# El PDF (book.pdf) sí sale de book.org y está al día.
#
# LO QUE HACE FALTA ARREGLAR
# En book.org los seis capítulos numerados van dentro de bloques
# \chapter* de export latex. Pandoc no ve ahí un encabezado, así que el
# EPUB saldría con todo el cuerpo apilado en una sola sección. Aquí se
# sacan a encabezados org de nivel 1 sobre una copia temporal; book.org
# no se toca, que es de donde sale el PDF con emacs.

set -e
cd "$(dirname "$0")"

python3 - <<'PY'
import re
from pathlib import Path
t = Path('book.org').read_text()

def arregla(m):
    bloque = m.group(0)
    tit = re.search(r'\\chapter\*\{(.+?)\}', bloque)
    if not tit:
        return bloque
    cabeza = "#+BEGIN_EXPORT latex\n\\cleardoublepage\n"
    part = re.search(r'(\\part\{.+?\})', bloque)
    if part:
        cabeza += part.group(1) + "\n"
    return cabeza + "#+END_EXPORT\n\n* " + tit.group(1) + "\n"

t = re.sub(r'#\+BEGIN_EXPORT latex\n(?:(?!#\+END_EXPORT).)*?\\chapter\*\{.*?#\+END_EXPORT\n',
           arregla, t, flags=re.S)

# "Índice" existe para que el exportador de emacs coloque ahí el índice a
# mano, y "Índice Alfabético" para un \printindex que lleva años comentado.
# En el EPUB las dos salen como secciones vacías. Fuera.
t = re.sub(r'\* Índice\n(?:(?!\* Prólogo).)*', '', t, flags=re.S)
t = re.sub(r'\* Índice Alfabético\n(?:(?!\* ).)*', '', t, flags=re.S)
Path('/tmp/cel_build.org').write_text(t)
PY

# Sin --toc: el EPUB ya lleva su índice de navegación, que es el que usa el
# lector. Con los dos parecía duplicado.
pandoc /tmp/cel_build.org -o crecer_en_libertad.epub

echo
echo "  EPUB  $(python3 -c "import zipfile;print(len([n for n in zipfile.ZipFile('crecer_en_libertad.epub').namelist() if n.endswith('.xhtml')]))") secciones"
