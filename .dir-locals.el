((org-mode . ((eval . (progn
                         (setq org-latex-classes
                               '(("book"
                                  "\\documentclass{book}"
                                  ("\\chapter{%s}" . "\\chapter*{%s}")
                                  ("\\section{%s}" . "\\section*{%s}")
                                  ("\\subsection{%s}" . "\\subsection*{%s}")
                                  ("\\subsubsection{%s}" . "\\subsubsection*{%s}"))))))
              (org-export-headline-levels . 3))))
