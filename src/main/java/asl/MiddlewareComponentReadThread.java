package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.Queue;

/**
 * This class is responsible for reading values from memcached and returning responses to the client.
 */
public class MiddlewareComponentReadThread implements Runnable {

    Integer componentId;
    Integer threadId;

    private static final Logger log = LogManager.getLogger(MiddlewareComponentReadThread.class);

    public MiddlewareComponentReadThread(Integer componentId, Integer threadId, Queue<Request> readQueue) {
        this.componentId = componentId;
        this.threadId = threadId;

        // TODO start connection to our memcached server using MemcachedConnection
        // TODO


        log.info(String.format("Component #%d ReadThread #%d initialised.", componentId, threadId));
    }

    @Override
    public void run() {
        // TODO start taking stuff from queue and executing it
    }
}
