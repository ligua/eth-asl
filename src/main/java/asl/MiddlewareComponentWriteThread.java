package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

/**
 * This class is responsible for writing values to memcached and returning responses to the client.
 */
public class MiddlewareComponentWriteThread implements Runnable {

    private static final Logger log = LogManager.getLogger(MiddlewareComponentWriteThread.class);

    @Override
    public void run() {
        // TODO
    }
}
