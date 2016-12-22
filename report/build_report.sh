echo "Copying report to the right place..."
cp report/milestone3.pdf pungast-milestone3.pdf

echo "Pushing to GitHub..."
git add report/milestone1.pdf report/milestone1.tex pungast-milestone1.pdf
git commit -m"auto-build report, $1"
git push origin master

echo "Pushing to GitLab..."
git push gitlab master


echo "Done."
