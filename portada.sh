#!/bin/bash
# Genera las portadas de los dos libros.
#
#     ./portada.sh
#
# Saca cuatro ficheros:
#   cover_es.pdf / cover_es.png    Crecer en Libertad
#   cover_en.pdf / cover_en.png    No Homework, No Marks
#
# El PDF se antepone al libro con pdfunite; el PNG es el que lleva el EPUB
# como cubierta. Los dos salen del mismo LaTeX, así que no se descuadran.
#
# Los colores son los de ferrera.me (--paper, --ink, --muted, --rule), para
# que la portada no parezca de otro sitio que la página donde se compra.
# La tipografía es Libertinus Serif, la misma del interior.

set -e
cd "$(dirname "$0")"

portada() {   # $1 salida  $2 título1  $3 título2  $4 subtítulo  $5 pie
  cat > /tmp/portada.tex <<TEX
\\documentclass[12pt]{article}
\\usepackage[paperwidth=6in,paperheight=9in,margin=0pt]{geometry}
\\usepackage{fontspec}
\\usepackage{xcolor}
\\setmainfont{Libertinus Serif}
\\definecolor{paper}{HTML}{F1F0EC}
\\definecolor{ink}{HTML}{1A1815}
\\definecolor{muted}{HTML}{6E6A61}
\\definecolor{rule}{HTML}{D2CFC6}
\\pagecolor{paper}
\\color{ink}
\\pagestyle{empty}
\\parindent=0pt
\\begin{document}
\\centering
% Un filete fino por dentro del borde, como el de las fichas de cartulina.
\\vspace*{10mm}
{\\color{rule}\\rule{\\dimexpr\\paperwidth-24mm\\relax}{0.4pt}}

\\vspace*{42mm}
{\\fontsize{30}{36}\\selectfont\\scshape $2\\par}
\\vspace{2mm}
{\\fontsize{30}{36}\\selectfont\\scshape $3\\par}

\\vspace{9mm}
{\\color{muted}\\fontsize{14}{18}\\selectfont\\itshape $4\\par}

\\vfill

{\\color{rule}\\rule{28mm}{0.4pt}\\par}
\\vspace{6mm}
{\\fontsize{13}{16}\\selectfont Juan Manuel Ferrera\\par}
\\vspace{3mm}
{\\color{muted}\\fontsize{9}{11}\\selectfont $5\\par}

\\vspace*{14mm}
{\\color{rule}\\rule{\\dimexpr\\paperwidth-24mm\\relax}{0.4pt}}
\\vspace*{10mm}
\\end{document}
TEX
  xelatex -interaction=batchmode -output-directory=/tmp /tmp/portada.tex >/dev/null 2>&1
  cp /tmp/portada.pdf "$1.pdf"
  # 1800x2700 a 300 ppp: lo que piden las tiendas para una cubierta 6x9.
  pdftoppm -png -r 300 -singlefile "$1.pdf" "$1"
}

portada cover_es "Crecer" "en Libertad" "Aprendiendo juntos" "ferrera.me"
portada cover_en "No Homework," "No Marks" "Growing in Freedom" "ferrera.me"

echo
for f in cover_es cover_en; do
  echo "  $f.png  $(sips -g pixelWidth -g pixelHeight $f.png 2>/dev/null | awk '/pixel/{printf "%s ", $2}')"
done
