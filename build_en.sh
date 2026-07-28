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

grep -v "^#+LATEX_HEADER" book_en.org | grep -v "^#+LATEX_CLASS" > /tmp/gif_build.org

cat > /tmp/gif_header.tex <<'TEX'
\DeclareTextCommandDefault{\textquote}[1]{``#1''}
\providecommand{\startmainmatter}{\mainmatter}
TEX

pandoc /tmp/gif_build.org -o growing_in_freedom.pdf \
  --pdf-engine=xelatex --toc -H /tmp/gif_header.tex \
  -V documentclass=book -V classoption=twoside \
  -V geometry:paperwidth=6in -V geometry:paperheight=9in \
  -V geometry:inner=15mm -V geometry:outer=10mm \
  -V geometry:top=13mm -V geometry:bottom=13mm \
  -V mainfont="Libertinus Serif" -V fontsize=12pt

pandoc book_en.org -o growing_in_freedom.epub --toc

echo
echo "  PDF   $(pdfinfo growing_in_freedom.pdf | awk '/^Pages/{print $2}') páginas"
echo "  EPUB  $(python3 -c "import zipfile;print(len([n for n in zipfile.ZipFile('growing_in_freedom.epub').namelist() if n.endswith('.xhtml')]))") secciones"
