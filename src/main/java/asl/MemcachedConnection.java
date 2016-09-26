package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.Closeable;

/**
 * One connection with a memcached instance.
 * Each write thread should have one MemcachedConnection instance *per memcached server*, so R connections in total.
 * Each read thread should have one MemcachedConnection with its designated memcached server, so 1 connection in total.
 */
class MemcachedConnection implements Closeable {

    private static final Logger log = LogManager.getLogger(MemcachedConnection.class);


    public void sendRequest(Request r) {
        String requestRaw = r.getRequestRaw();
        // TODO send requestRaw and set response appropriately
        String response = "foo";

        r.respond("lala shitty response to " + r);
    }


    @Override
    public void close() {
        // TODO
    }

}
