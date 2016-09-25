package test.java.asl;

import main.java.asl.UniformHasher;
import org.junit.After;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;

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

}