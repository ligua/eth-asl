package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.Queue;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;

/**
 * The class responsible for queueing for one memcached instance.
 * In the example architecture, there are 3 of these.
 */
public class MiddlewareComponent {

    private static final Logger log = LogManager.getLogger(MiddlewareComponent.class);

    Queue readQueue;
    Queue writeQueue;

    Integer componentId;

    MiddlewareComponent(Integer componentId, Integer numReadThreads) {

        this.componentId = componentId;

        // Initialise queues
        readQueue = new LinkedBlockingQueue<>();
        writeQueue = new LinkedBlockingQueue<>(); // TODO use non-blocking queue here?

        ExecutorService executor = Executors.newCachedThreadPool(); // TODO read about newCachedThreadPool()

        // Initialise and start write thread
        MiddlewareComponentWriteThread writeThread = new MiddlewareComponentWriteThread(componentId, writeQueue);
        executor.submit(writeThread);

        // Initialise read threads
        for(int threadId=0; threadId<numReadThreads; threadId++) {
            MiddlewareComponentReadThread readThread =
                    new MiddlewareComponentReadThread(componentId, threadId, readQueue);
            executor.submit(readThread);
        }


        log.info(String.format("MiddlewareComponent #%d initialised.", componentId));
    }

}
