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
grep -v "^#+LATEX_HEADER" book_en.org \
  | grep -v "^#+LATEX_CLASS" \
  | grep -v '^\\addcontentsline' \
  | grep -v '^\\startmainmatter' \
  | grep -v '^:UNNUMBERED:' \
  > /tmp/gif_build.org

cat > /tmp/gif_header.tex <<'TEX'
\DeclareTextCommandDefault{\textquote}[1]{``#1''}
% Los títulos ya llevan su número escrito ("1. An Introduction..."), así que
% LaTeX no debe añadir otro encima.
\setcounter{secnumdepth}{-1}
TEX

pandoc /tmp/gif_build.org -o growing_in_freedom.pdf \
  --pdf-engine=xelatex --toc -H /tmp/gif_header.tex \
  -V documentclass=book -V classoption=twoside \
  -V geometry:paperwidth=6in -V geometry:paperheight=9in \
  -V geometry:inner=15mm -V geometry:outer=10mm \
  -V geometry:top=13mm -V geometry:bottom=13mm \
  -V mainfont="Libertinus Serif" -V fontsize=12pt

# Sin --toc a propósito: el EPUB ya lleva su índice de navegación (nav.xhtml),
# que es el que usa el lector. Con --toc salían los dos y parecía duplicado.
pandoc book_en.org -o growing_in_freedom.epub

echo
echo "  PDF   $(pdfinfo growing_in_freedom.pdf | awk '/^Pages/{print $2}') páginas"
echo "  EPUB  $(python3 -c "import zipfile;print(len([n for n in zipfile.ZipFile('growing_in_freedom.epub').namelist() if n.endswith('.xhtml')]))") secciones"
