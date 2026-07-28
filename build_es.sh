#!/bin/bash
# Construye la edición española desde book.org.
#
#     ./build_es.sh   ->  crecer_en_libertad.pdf  y  crecer_en_libertad.epub
#
# Antes el PDF salía de emacs (book.pdf) y aquí solo se le remendaban páginas
# sueltas. Ya no: se construye entero con pandoc, igual que el inglés, así que
# las dos ediciones pasan por la misma tubería y los arreglos valen para las
# dos. book.org y book.pdf no se tocan.
#
# Lo que arregla, todo por lo mismo: los bloques LaTeX del fichero están
# escritos para el exportador de emacs, que numera y monta el índice de otra
# manera que pandoc.
#
#   \textquote{}      LO MÁS IMPORTANTE. Las comillas van así, 193 veces.
#                     Para pandoc es LaTeX crudo, y en EPUB el LaTeX crudo se
#                     TIRA: el fichero salía sin una sola frase entrecomillada
#                     —faltaban casi dos mil palabras, y eran los diálogos—.
#                     Se convierten en comillas de verdad antes de nada.
#
#   \chapter*         Los seis capítulos van dentro de bloques export. Pandoc
#                     no ve ahí un encabezado, así que el EPUB salía con todo
#                     el cuerpo apilado en una sola sección.
#
#   \index{}          El índice alfabético lleva años desactivado. No imprimen
#                     nada, y pegados a una cursiva la rompen: salían las
#                     barras a la vista.
#
#   \addcontentsline  Hace falta con emacs, que saca \chapter*. Pandoc saca
#                     \chapter, que ya crea la entrada. Con las dos, cada
#                     sección del principio salía DOS VECES en el índice.
#
#   :UNNUMBERED:      Pandoc lo convierte en \chapter*, y un \chapter* no
#                     actualiza la cabecera de página: la bibliografía y
#                     "Sobre el Autor" salían con "El Futuro de la Educación"
#                     arriba. Como abajo se apaga la numeración entera,
#                     quitarlo no numera nada y arregla la cabecera.
#
#   #+TITLE y demás   Hacen que pandoc monte SU portada al principio, y la de
#                     verdad acababa detrás del índice, en mitad del libro.
#
#   Índice / Índice Alfabético
#                     Dos capítulos vacíos: el primero solo tenía el título
#                     (el índice de verdad lo pone \tableofcontents justo
#                     después) y el segundo nunca tuvo nada.

set -e
cd "$(dirname "$0")"

python3 - <<'PY'
import re
from pathlib import Path
t = Path('book.org').read_text()

# Ojo con el cuerpo: casi todos estos bloques solo llevan el título y la
# fontanería, pero el de "Sobre el Autor" trae dentro la biografía entera.
# Sustituir el bloque por el título a secas se la comía: el capítulo salía
# con el encabezado y nada debajo.
FONTANERIA = ('\\cleardoublepage', '\\clearpage', '\\part{', '\\chapter*{',
              '\\addcontentsline', '\\markboth', '\\thispagestyle', '\\vfill', '%')

def saca_capitulo(m):
    bloque = m.group(0)
    tit = re.search(r'\\chapter\*\{(.+?)\}', bloque)
    if not tit:
        return bloque
    cabeza = "#+BEGIN_EXPORT latex\n\\cleardoublepage\n"
    part = re.search(r'(\\part\{.+?\})', bloque)
    if part:
        cabeza += part.group(1) + "\n"
    cabeza += "#+END_EXPORT\n\n* " + tit.group(1) + "\n"

    dentro = bloque.split('#+END_EXPORT')[0].split('\n')
    cuerpo = [l for l in dentro
              if l.strip() and not l.strip().startswith(FONTANERIA)
              and not l.startswith('#+BEGIN_EXPORT')]
    if cuerpo:
        texto = '\n'.join(cuerpo)
        texto = re.sub(r'\\textbf\{([^{}]*)\}', r'*\1*', texto)
        texto = re.sub(r'\\textit\{([^{}]*)\}', r'/\1/', texto)
        cabeza += "\n" + texto + "\n"
    return cabeza

t = re.sub(r'#\+BEGIN_EXPORT latex\n(?:(?!#\+END_EXPORT).)*?\\chapter\*\{.*?#\+END_EXPORT\n',
           saca_capitulo, t, flags=re.S)

t = re.sub(r'\* Índice\n(?:(?!\* Prólogo).)*', '', t, flags=re.S)
t = re.sub(r'\* Índice Alfabético\n(?:(?!\* ).)*', '', t, flags=re.S)

t = re.sub(r'\\index\{[^{}]*\}', '', t)
prev = None
while prev != t:
    prev = t
    t = re.sub(r'\\textquote\{([^{}]*)\}', r'«\1»', t)
t = re.sub(r'([A-Za-zÁÉÍÓÚáéíóúñ])/(—|\\\\)', r'\1/ \2', t)
t = re.sub(r'^\*\*\*\* (.+)$', r'*\1*', t, flags=re.M)

# Números romanos hasta el capítulo 1. Va dentro del cuerpo y no en el
# preámbulo porque la plantilla de pandoc mete su propio \mainmatter justo
# antes, y eso dejaba la portada en arábigos: el libro acababa con dos
# páginas "1" y el índice mandaba a sitios equivocados.
t = t.replace("#+BEGIN_EXPORT latex\n% Half title page",
              "#+BEGIN_EXPORT latex\n\\pagenumbering{roman}\n% Half title page", 1)

# El índice, después de la portada y la dedicatoria. Con --toc, pandoc lo
# pone delante de todo y la portada queda detrás, en la página 7.
t = t.replace("\\cleardoublepage\n#+END_EXPORT\n\n* Prólogo",
              "\\cleardoublepage\n\\tableofcontents\n\\cleardoublepage\n#+END_EXPORT\n\n* Prólogo", 1)

# Sin contar la línea que define el comando en la cabecera LaTeX.
sobran = len([l for l in t.split('\n') if '\\textquote{' in l and not l.startswith('#+LATEX_HEADER')])
if sobran:
    print(f'  ! quedan {sobran} \\textquote sin convertir')

Path('/tmp/cel_epub.org').write_text(t)

# Para el PDF, además, fuera lo que pelea con la plantilla de pandoc.
fuera = ('#+LATEX_HEADER', '#+LATEX_CLASS', '#+TITLE', '#+SUBTITLE',
         '#+AUTHOR', '#+DATE', '\\addcontentsline', ':UNNUMBERED:')
pdf = '\n'.join(l for l in t.split('\n') if not l.startswith(fuera))
Path('/tmp/cel_pdf.org').write_text(pdf)
PY

cat > /tmp/cel_header.tex <<'TEX'
% El salto de romanos a arábigos, al acabar los agradecimientos.
\providecommand{\startmainmatter}{\clearpage\pagenumbering{arabic}\setcounter{page}{1}}
% Los títulos ya llevan su número escrito ("1. Introducción a..."), así que
% LaTeX no debe añadir otro encima.
\setcounter{secnumdepth}{-1}
TEX

pandoc /tmp/cel_pdf.org -o /tmp/cel_cuerpo.pdf \
  --pdf-engine=xelatex -H /tmp/cel_header.tex \
  -V title-meta="Crecer en Libertad" -V author-meta="Juan Manuel Ferrera Díaz" \
  -V lang=es \
  -V documentclass=book -V classoption=twoside \
  -V geometry:paperwidth=6in -V geometry:paperheight=9in \
  -V geometry:inner=15mm -V geometry:outer=10mm \
  -V geometry:top=13mm -V geometry:bottom=13mm \
  -V mainfont="Libertinus Serif" -V fontsize=12pt

# La cubierta la genera ./portada.sh.
pandoc /tmp/cel_epub.org -o crecer_en_libertad.epub --epub-cover-image=cover_es.png

pdfunite cover_es.pdf /tmp/cel_cuerpo.pdf /tmp/cel_con_portada.pdf

# pdfunite se lleva por delante el título del PDF, que es lo que ve el lector
# en la pestaña y en la biblioteca de su lector de libros.
printf '[ /Title (Crecer en Libertad) /Author (Juan Manuel Ferrera Diaz) /DOCINFO pdfmark\n' > /tmp/cel_meta.txt
gs -q -o crecer_en_libertad.pdf -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress \
   /tmp/cel_con_portada.pdf /tmp/cel_meta.txt

echo
echo "  PDF   $(pdfinfo crecer_en_libertad.pdf | awk '/^Pages/{print $2}') páginas"
echo "  EPUB  $(python3 -c "import zipfile;print(len([n for n in zipfile.ZipFile('crecer_en_libertad.epub').namelist() if n.endswith('.xhtml')]))") secciones"
