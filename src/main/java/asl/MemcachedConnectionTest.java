package main.java.asl;

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