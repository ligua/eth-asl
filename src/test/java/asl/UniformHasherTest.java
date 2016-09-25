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

    UniformHasher uh;

    @Before
    public void setUp() {
        uh = new UniformHasher(1, 1);
    }

    @After
    public void tearDown() {

    }

    /*@Test
    public void bytesToString() throws Exception {

    }*/

    @Test
    public void getHash() throws Exception {
        assertEquals(uh.getHash("taivo"), "30834776a9b6d5ac92969b8af8484859");
    }

}