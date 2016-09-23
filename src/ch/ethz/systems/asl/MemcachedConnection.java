package ch.ethz.systems.asl;

import java.io.Closeable;

/**
 * One connection with a memcached instance.
 * Each write thread should have one MemcachedConnection instance *per memcached server*, so R connections in total.
 * Each read thread should have one MemcachedConnection with its designated memcached server, so 1 connection in total.
 */
public class MemcachedConnection implements Closeable {

    @Override
    public void close() {
        // TODO
    }

}
