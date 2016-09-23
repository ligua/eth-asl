package ch.ethz.systems.asl;

import ch.ethz.systems.asl.justtesting.CrunchifyNIOServer;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

/**
 * This class is responsible for reading values from memcached and returning responses to the client.
 */
public class MiddlewareComponentReadThread extends Thread {

    private static final Logger log = LogManager.getLogger(MiddlewareComponentReadThread.class);

    @Override
    public void run() {

    }
}
