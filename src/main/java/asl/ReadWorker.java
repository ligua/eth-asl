package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.Queue;
import java.util.concurrent.BlockingQueue;

/**
 * This class is responsible for reading values from memcached and returning responses to the client.
 */
class ReadWorker implements Runnable {

    private Integer componentId;
    private Integer threadId;
    private BlockingQueue<Request> readQueue;

    private static final Logger log = LogManager.getLogger(ReadWorker.class);

    ReadWorker(Integer componentId, Integer threadId, BlockingQueue<Request> readQueue) {
        this.componentId = componentId;
        this.threadId = threadId;
        this.readQueue = readQueue;

        // TODO start connection to our memcached server using MemcachedConnection
        // TODO
    }

    @Override
    public void run() {
        log.info(String.format("%s Component #%d ReadWorker #%d started.", getName(), componentId, threadId));

        while(true) {
            // log.info("Read queue top element is " + readQueue.peek());
            if(!readQueue.isEmpty()) {
                try {
                    Request r = readQueue.take();
                    log.info("Processing request " + r);
                } catch (InterruptedException ex) {
                    log.error(ex);
                }
            }
        }
        // TODO start taking stuff from queue and executing it
    }

    public String getName() {
        return String.format("c%dr%d", componentId, threadId);
    }
}
