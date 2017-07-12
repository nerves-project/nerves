# Nerves Cheat Sheet

For best results, print in landscape mode without page scaling @ 600dpi.  

## Render PDF in Debian/Ubuntu
1. `sudo apt-get install texlive-latex-recommended texlive-fonts-recommended`
2. `make`
3. Open `cheatsheet.pdf`.
4. GNOME's document viewer Evince will automatically refresh if you edit and run `make` while it's open.

## Editing via Overleaf

Alternatively, you can signup for Overleaf, a free web application for editing LaTeX documents with built-in preview.  Paste the source from `cheatsheet.tex` into a new document while in "Source" mode.  You will need to attach `nerves-logo.eps` to your project by clicking "PROJECT" and attaching the EPS file.
