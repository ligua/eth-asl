package ch.ethz.systems.asl;

import ch.ethz.systems.asl.justtesting.CrunchifyNIOServer;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.Closeable;

/**
 * One connection with a memcached instance.
 * Each write thread should have one MemcachedConnection instance *per memcached server*, so R connections in total.
 * Each read thread should have one MemcachedConnection with its designated memcached server, so 1 connection in total.
 */
public class MemcachedConnection implements Closeable {

    private static final Logger log = LogManager.getLogger(MemcachedConnection.class);

    @Override
    public void close() {
        // TODO
    }

}
