echo "Plotting trace (R=3) results..."
Rscript scripts/r/trace.r results/trace_rep3

echo "Plotting baseline results..."
Rscript scripts/r/baseline.r results/baseline

echo "Building report PDF..."
cd report
pdflatex milestone1.tex
cd ..

echo "Copying report to the right place..."
cp report/milestone1.pdf pungast-milestone1.pdf

echo "Pushing to GitHub..."
git add report/milestone1.pdf report/milestone1.tex pungast-milestone1.pdf
git commit -m'auto-build report'
git push origin master

echo "Pushing to GitLab..."
git push gitlab master


echo "Done."
