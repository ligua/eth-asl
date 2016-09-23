package ch.ethz.systems.asl;

import ch.ethz.systems.asl.justtesting.CrunchifyNIOServer;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

/**
 * This class is responsible for writing values to memcached and returning responses to the client.
 */
public class MiddlewareComponentWriteThread extends Thread {

    private static final Logger log = LogManager.getLogger(MiddlewareComponentWriteThread.class);

    @Override
    public void run() {

    }
}
