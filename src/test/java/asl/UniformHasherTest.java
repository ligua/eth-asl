package test.java.asl;

import main.java.asl.UniformHasher;
import main.java.asl.Util;
import org.junit.Test;

import java.util.*;

import static org.junit.Assert.*;

/**
 * Created by taivo on 25/09/16.
 */
public class UniformHasherTest {

    /*@Test
    public void bytesToString() throws Exception {

    }*/

    @Test
    public void getHash() throws Exception {
        UniformHasher uh = new UniformHasher(1, 0);
        assertEquals(Util.bytesToString(uh.getHash("taivo")), "30834776a9b6d5ac92969b8af8484859");
    }

    public void getTargetMachinesSingle(Integer numMachines, Integer replicationFactor) throws Exception {
        UniformHasher uh = new UniformHasher(numMachines, replicationFactor);

        String testString = "taivo";

        assertEquals(uh.getTargetMachines(uh.getPrimaryMachine(testString)).size(), (long) replicationFactor);
        assertEquals(uh.getTargetMachines(uh.getPrimaryMachine(testString)).get(0), uh.getPrimaryMachine(testString));
    }

    @Test
    public void getTargetMachines() throws Exception {
        getTargetMachinesSingle(1, 1);
        getTargetMachinesSingle(13, 10);
    }

    @Test
    public void testUniformity() throws Exception {
        Integer numMachines = 13;
        Integer replicationFactor = 10;
        UniformHasher uh = new UniformHasher(numMachines, replicationFactor);

        Integer[] occurrences = new Integer[numMachines];
        for(int i=0; i<numMachines; i++) {
            occurrences[i]= 0;
        }

        Integer numSamples = 1000000;
        for(int i=0; i<numSamples; i++) {
            // Generate random string
            String randomString = UUID.randomUUID().toString();

            // Find machine for this string and remember result
            occurrences[uh.getPrimaryMachine(randomString)] += 1;
        }

        // If difference between max and min is > 20%, we should probably worry
        List occurrenceList = new ArrayList<Integer>(Arrays.asList(occurrences));
        Integer min = (Integer) Collections.min(occurrenceList);
        Integer max = (Integer) Collections.max(occurrenceList);
        Integer diff = max - min;
        assertTrue((double) diff / min < 0.05);

        for(int i=0; i<occurrences.length; i++) {
            System.out.println(String.format("Machine %3d got %10d hits.", i, occurrences[i]));
        }
    }

    @Test
    public void testDeterminism() throws Exception {
        String testString1 = "taivo";
        String testString2 = "pungas";

        UniformHasher uh1 = new UniformHasher(1, 1);
        Integer machine11 = uh1.getPrimaryMachine(testString1);
        Integer machine21 = uh1.getPrimaryMachine(testString2);

        UniformHasher uh2 = new UniformHasher(1, 1);
        Integer machine12 = uh2.getPrimaryMachine(testString1);
        Integer machine22 = uh2.getPrimaryMachine(testString2);

        assertEquals(machine11, machine12);
        assertEquals(machine21, machine22);
    }

}