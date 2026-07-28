#!/bin/bash
# Construye la edición inglesa desde book_en.org.
#
#     ./build_en.sh
#
# Saca growing_in_freedom.pdf (6x9, el formato de KDP) y
# growing_in_freedom.epub.
#
# Se usa pandoc y no el exportador de org porque aquí no hay emacs. Dos
# cosas hay que saber:
#
#   1. Las líneas #+LATEX_HEADER del fichero chocan con los paquetes que
#      mete pandoc por su cuenta (microtype da "option clash"). Se quitan
#      para el PDF y la maqueta se pasa por -V.
#   2. \textquote y \startmainmatter se definen en esas cabeceras, así que
#      hay que volver a declararlas aparte o LaTeX se para.
#
# Los seis capítulos numerados son encabezados org de nivel 1, no bloques
# \chapter* dentro de export latex como en la edición española. Si se
# vuelven a meter en un bloque, el EPUB pierde la estructura y salen todos
# los capítulos pegados en una sola sección.

set -e
cd "$(dirname "$0")"

# Se limpia el fichero para pandoc. Tres cosas, y las tres por el mismo
# motivo: los bloques LaTeX del original están escritos para el exportador
# de emacs, que numera y monta el índice de otra manera.
#
#   \addcontentsline  hacía falta porque org saca \chapter* (sin entrada en
#                     el índice). Pandoc saca \chapter, que ya la crea. Con
#                     las dos, cada sección del principio salía DOS VECES en
#                     el índice: Contents, Contents, Foreword, Foreword...
#
#   \startmainmatter  reinicia el contador de páginas. El libro acababa con
#                     dos páginas "1": el prólogo en la 11 y el capítulo 1
#                     en la 3. El índice mandaba a sitios equivocados.
#
#   #+LATEX_HEADER    choca con los paquetes de pandoc (microtype da
#                     "option clash").
#   :UNNUMBERED:      pandoc lo convierte en \chapter*, y un \chapter* no
#                     actualiza la cabecera de página. El epílogo, el
#                     apéndice y la bibliografía salían con "6. WHAT COMES
#                     NEXT" arriba. Como abajo se apaga la numeración
#                     entera, quitarlo no numera nada y arregla la cabecera.
#   #+TITLE y compañía  hacen que pandoc monte SU portada automática al
#                     principio. El libro acababa con dos portadas: la de
#                     pandoc delante, y la de verdad enterrada detrás del
#                     índice, en la página 7. Se quitan aquí y el título
#                     para los metadatos del PDF se pone abajo, a mano.
grep -v "^#+LATEX_HEADER" book_en.org \
  | grep -v "^#+LATEX_CLASS" \
  | grep -v "^#+TITLE" | grep -v "^#+SUBTITLE" \
  | grep -v "^#+AUTHOR" | grep -v "^#+DATE" \
  | grep -v '^\\addcontentsline' \
  | grep -v '^:UNNUMBERED:' \
  > /tmp/gif_build.org

# LO MÁS IMPORTANTE DE ESTE SCRIPT
#
# El texto usa \textquote{...} para las comillas, 193 veces en el original.
# Para pandoc eso es LaTeX crudo, y en el EPUB el LaTeX crudo SE TIRA: el
# fichero salía sin una sola frase entrecomillada. Faltaban dos mil palabras
# y eran justo los diálogos ("Papá, ¿estás bien de la cabeza?", "Porque
# podemos", la conversación con el director). Aquí se convierten en comillas
# tipográficas de verdad, que valen igual en PDF y en EPUB.
#
# Los \index{...} se quitan: el índice alfabético lleva años desactivado
# (\printindex está comentado), no imprimen nada, y pegados a una cursiva la
# rompen: "/A small patch/\index{garden}:" salía con las barras a la vista.
python3 - <<'PY'
import re
from pathlib import Path

def limpia(t):
    t = re.sub(r'\\index\{[^{}]*\}', '', t)
    # Se resuelve de dentro afuera, por si alguno quedara anidado.
    prev = None
    while prev != t:
        prev = t
        t = re.sub(r'\\textquote\{([^{}]*)\}', r'“\1”', t)
    # Una cursiva pegada a una raya o a un salto de línea no la reconoce
    # pandoc y salen las barras impresas: "/homeschooling/—no por capricho".
    t = re.sub(r'([A-Za-z])/(—|\\\\)', r'\1/ \2', t)
    # Con #+OPTIONS H:3 los encabezados de cuarto nivel no son encabezados.
    # Emacs los saca como viñetas; pandoc los numera ("5. The sweet shop"),
    # que inventa un orden que no significa nada. Van como párrafo destacado.
    t = re.sub(r'^\*\*\*\* (.+)$', r'*\1*', t, flags=re.M)
    return t

for f in ('/tmp/gif_build.org', '/tmp/gif_epub.org'):
    origen = Path('book_en.org') if f.endswith('epub.org') else Path(f)
    Path(f).write_text(limpia(origen.read_text()))

sobran = len(re.findall(r'\\textquote', Path('/tmp/gif_build.org').read_text()))
print(f'  ! quedan {sobran} \\textquote sin convertir' if sobran else '', end='')
PY

cat > /tmp/gif_header.tex <<'TEX'
% Números romanos hasta que empieza el capítulo 1, arábigos a partir de ahí:
% lo normal en un libro. \startmainmatter es el que hace el salto y está en
% el bloque de los agradecimientos.
\providecommand{\startmainmatter}{\clearpage\pagenumbering{arabic}\setcounter{page}{1}}
% Los títulos ya llevan su número escrito ("1. An Introduction..."), así que
% LaTeX no debe añadir otro encima.
\setcounter{secnumdepth}{-1}
TEX

# Sin --toc: el índice lo coloca el propio fichero, después de la portada.
pandoc /tmp/gif_build.org -o growing_in_freedom.pdf \
  --pdf-engine=xelatex -H /tmp/gif_header.tex \
  -V title-meta="No Homework, No Marks" -V author-meta="Juan Manuel Ferrera Díaz" \
  -V documentclass=book -V classoption=twoside \
  -V geometry:paperwidth=6in -V geometry:paperheight=9in \
  -V geometry:inner=15mm -V geometry:outer=10mm \
  -V geometry:top=13mm -V geometry:bottom=13mm \
  -V mainfont="Libertinus Serif" -V fontsize=12pt

# Sin --toc a propósito: el EPUB ya lleva su índice de navegación (nav.xhtml),
# que es el que usa el lector. Con --toc salían los dos y parecía duplicado.
pandoc /tmp/gif_epub.org -o growing_in_freedom.epub

echo
echo "  PDF   $(pdfinfo growing_in_freedom.pdf | awk '/^Pages/{print $2}') páginas"
echo "  EPUB  $(python3 -c "import zipfile;print(len([n for n in zipfile.ZipFile('growing_in_freedom.epub').namelist() if n.endswith('.xhtml')]))") secciones"
