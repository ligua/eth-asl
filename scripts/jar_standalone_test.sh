mkdir ../test-jar
NEWESTJAR=`ls -Art dist/ | tail -n 1`
cp dist/$NEWESTJAR ../test-jar

echo "JAR contents:"
jar -tf ../test-jar/$NEWESTJAR

java -jar ../test-jar/$NEWESTJAR -l 127.0.0.1 -p 11212 -t 5 -r 2 -m 127.0.0.1:11210 127.0.0.1:11211 # run the latest-modified JAR