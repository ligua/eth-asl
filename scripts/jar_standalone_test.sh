mkdir ../test-jar
NEWESTJAR=`ls -Art dist/ | tail -n 1`
cp dist/$NEWESTJAR ../test-jar

echo "JAR contents:"
jar -tf ../test-jar/$NEWESTJAR

java -jar ../test-jar/$NEWESTJAR # run the latest-modified JAR