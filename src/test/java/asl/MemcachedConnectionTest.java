package test.java.asl;

import main.java.asl.MemcachedConnection;
import main.java.asl.Request;
import org.junit.Test;

import static org.junit.Assert.*;

public class MemcachedConnectionTest {

    @Test
    public void sendRequest() {
        MemcachedConnection mc = new MemcachedConnection();

        Request r = new Request("get asd", null);

        mc.sendRequest(r);
    }

}