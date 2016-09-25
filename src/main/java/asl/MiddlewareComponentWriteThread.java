package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.Queue;

/**
 * This class is responsible for writing values to memcached and returning responses to the client.
 */
public class MiddlewareComponentWriteThread implements Runnable {

    private static final Logger log = LogManager.getLogger(MiddlewareComponentWriteThread.class);

    Integer componentId;

    public MiddlewareComponentWriteThread(Integer componentId, Queue<Request> writeQueue) {
        this.componentId = componentId;
        // TODO




        log.info(String.format("Component #%d WriteThread initialised.", componentId));
    }

    @Override
    public void run() {
        // TODO
    }
}
