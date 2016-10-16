echo "Plotting trace (R=1) results..."
Rscript scripts/r/trace.r results/trace_rep1

echo "Plotting trace (R=3) results..."
Rscript scripts/r/trace.r results/trace_rep3

echo "Plotting baseline results..."
Rscript scripts/r/baseline.r results/baseline

echo "Building report PDF..."
cd report
pdflatex milestone1.tex
cd ..

echo "Done."
