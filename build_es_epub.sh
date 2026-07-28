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

# LO MÁS IMPORTANTE DE AQUÍ
#
# El libro usa \textquote{...} para las comillas, 193 veces. Para pandoc eso
# es LaTeX crudo, y en el EPUB el LaTeX crudo SE TIRA: el fichero salía sin
# una sola frase entrecomillada. Faltaban casi dos mil palabras y eran los
# diálogos: "Papá, ¿estás bien de la cabeza?", "Porque podemos", lo que le
# dijo el director. Aquí se convierten en comillas de verdad.
#
# Los \index{...} se quitan: el índice alfabético lleva años desactivado y,
# pegados a una cursiva, la rompen y salen las barras impresas.
t = re.sub(r'\\index\{[^{}]*\}', '', t)
prev = None
while prev != t:
    prev = t
    t = re.sub(r'\\textquote\{([^{}]*)\}', r'«\1»', t)
# Una cursiva pegada a una raya o a un salto de línea no la reconoce pandoc y
# salen las barras impresas: "/homeschooling/—no por capricho". Se separa.
t = re.sub(r'([A-Za-zÁÉÍÓÚáéíóúñ])/(—|\\\\)', r'\1/ \2', t)

# Con #+OPTIONS H:3 los encabezados de cuarto nivel no son encabezados.
# Emacs los saca como viñetas; pandoc los numera, que inventa un orden que no
# significa nada. Van como párrafo destacado.
t = re.sub(r'^\*\*\*\* (.+)$', r'*\1*', t, flags=re.M)

sobran = len(re.findall(r'\\textquote', t))
if sobran:
    print(f'  ! quedan {sobran} \\textquote sin convertir')

Path('/tmp/cel_build.org').write_text(t)
PY

# Sin --toc: el EPUB ya lleva su índice de navegación, que es el que usa el
# lector. Con los dos parecía duplicado.
# La cubierta la genera ./portada.sh.
pandoc /tmp/cel_build.org -o crecer_en_libertad.epub --epub-cover-image=cover_es.png

# El PDF español sale de emacs (book.pdf) y aquí no hay emacs, así que no se
# regenera entero. Pero la página de créditos (la 4) llevaba dos ISBN de
# relleno, "979-8-XXXX-XXXX-X", y este libro se vende en PDF y EPUB, donde no
# hace falta ISBN. Así que se rehace esa página sola, con el mismo LaTeX del
# original menos los ISBN, y se empalma en su sitio. book.pdf no se toca.
cat > /tmp/cel_cred.tex <<'TEX'
\documentclass[12pt,twoside]{book}
\usepackage[paperwidth=6in,paperheight=9in,inner=15mm,outer=10mm,top=13mm,bottom=13mm]{geometry}
\usepackage{fontspec}
\setmainfont{Libertinus Serif}
\usepackage{setspace}\setstretch{1.15}
\pagestyle{empty}
\begin{document}
\thispagestyle{empty}
\vspace*{\fill}

\noindent
{\footnotesize
\textsc{Crecer en Libertad}: \textit{Aprendiendo juntos}\\[0.8em]
Copyright \copyright\ 2025 Juan Manuel Ferrera Díaz\\[0.8em]
Todos los derechos reservados.\\[1.2em]

Primera edición, 2025\\[1.2em]

Impreso en Estados Unidos de América\\[1.2em]

\textit{Para más información sobre educación en libertad, visita:}\\
\texttt{www.crecerenlibertad.org}
}

\vspace{2cm}
\end{document}
TEX
xelatex -interaction=batchmode -output-directory=/tmp /tmp/cel_cred.tex >/dev/null 2>&1

TOTAL=$(pdfinfo book.pdf | awk '/^Pages/{print $2}')
gs -q -o /tmp/cel_p1.pdf  -sDEVICE=pdfwrite -dFirstPage=1 -dLastPage=3        book.pdf
gs -q -o /tmp/cel_p3.pdf  -sDEVICE=pdfwrite -dFirstPage=5 -dLastPage=$TOTAL   book.pdf
pdfunite /tmp/cel_p1.pdf /tmp/cel_cred.pdf /tmp/cel_p3.pdf /tmp/cel_cuerpo.pdf

pdfunite cover_es.pdf /tmp/cel_cuerpo.pdf /tmp/cel_con_portada.pdf

# pdfunite se lleva por delante el título del PDF.
printf '[ /Title (Crecer en Libertad) /Author (Juan Manuel Ferrera Diaz) /DOCINFO pdfmark\n' > /tmp/cel_meta.txt
gs -q -o crecer_en_libertad.pdf -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress \
   /tmp/cel_con_portada.pdf /tmp/cel_meta.txt

echo
echo "  EPUB  $(python3 -c "import zipfile;print(len([n for n in zipfile.ZipFile('crecer_en_libertad.epub').namelist() if n.endswith('.xhtml')]))") secciones"
