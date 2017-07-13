all: once

once:
	pdflatex -halt-on-error *.tex > /dev/null

alert:
	pdflatex -halt-on-error *.tex

clean:
	rm -f *.log *.nlo *.idx *.synctex* *.aux *.toc *.out *eps-converted-to.pdf
