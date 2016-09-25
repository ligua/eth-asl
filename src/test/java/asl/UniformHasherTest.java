package test.java.asl;

import main.java.asl.UniformHasher;
import org.junit.Test;

import java.util.UUID;

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
        UniformHasher uh = new UniformHasher(1, 1);
        assertEquals(uh.bytesToString(uh.getHash("taivo")), "30834776a9b6d5ac92969b8af8484859");
    }

    @Test
    public void getAllMachines() throws Exception {
        Integer numMachines = 13;
        Integer replicationFactor = 10;
        UniformHasher uh = new UniformHasher(numMachines, replicationFactor);

        String testString = "taivo";

        assertEquals(uh.getAllMachines(testString).size(), (long) replicationFactor + 1);
        assertEquals(uh.getAllMachines(testString).get(0), uh.getPrimaryMachine(testString));
    }

    @Test
    public void testUniformity() throws Exception {
        Integer numMachines = 13;
        Integer replicationFactor = 10;
        UniformHasher uh = new UniformHasher(numMachines, replicationFactor);

        int[] occurrences = new int[numMachines];
        Integer numSamples = 1000000;
        for(int i=0; i<numSamples; i++) {
            // Generate random string
            String randomString = UUID.randomUUID().toString();

            // Find machine for this string and remember result
            occurrences[uh.getPrimaryMachine(randomString)] += 1;
        }

        for(int i=0; i<occurrences.length; i++) {
            System.out.println(String.format("Machine %3d got %10d hits.", i, occurrences[i]));
        }
    }

}