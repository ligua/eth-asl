package test.java.asl;

import main.java.asl.Request;
import org.junit.Test;

import static org.junit.Assert.*;

public class RequestTest {
    @Test
    /**
     * Test whether the key is parsed correctly.
     */
    public void getKey() throws Exception {

        Request r1 = new Request("set mykey 0 60 5", null);
        assert(r1.getKey().equals("mykey"));

        Request r2 = new Request("get lel", null);
        assert(r2.getKey().equals("lel"));

    }

}