# Makefile for the ProbOS manuscript
MAIN = main

all: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).tex references.bib
	pdflatex -interaction=nonstopmode $(MAIN).tex
	bibtex $(MAIN)
	pdflatex -interaction=nonstopmode $(MAIN).tex
	pdflatex -interaction=nonstopmode $(MAIN).tex

clean:
	rm -f *.aux *.bbl *.blg *.log *.out *.toc

cleanall: clean
	rm -f $(MAIN).pdf

.PHONY: all clean cleanall
