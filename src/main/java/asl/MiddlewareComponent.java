package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.List;
import java.util.Queue;
import java.util.concurrent.*;

/**
 * The class responsible for queueing for one memcached instance.
 * In the example architecture, there are 3 of these.
 */
public class MiddlewareComponent {

    private static final Logger log = LogManager.getLogger(MiddlewareComponent.class);

    BlockingQueue<Request> readQueue;
    BlockingQueue<Request> writeQueue;

    private Integer componentId;

    MiddlewareComponent(Integer componentId, Integer numReadThreads, List<Integer> targetMachines,
                        ExecutorService executor) {

        this.componentId = componentId;

        // Initialise queues
        readQueue = new ArrayBlockingQueue<>(MiddlewareMain.QUEUE_SIZE);
        writeQueue = new ArrayBlockingQueue<>(MiddlewareMain.QUEUE_SIZE);

        // Initialise and start write thread
        WriteWorker writeWorker = new WriteWorker(componentId, targetMachines, writeQueue);
        executor.submit(writeWorker);

        // Initialise read threads
        for(int threadId=0; threadId<numReadThreads; threadId++) {
            ReadWorker readWorker =
                    new ReadWorker(componentId, threadId, readQueue);
            executor.submit(readWorker);
        }


        log.info(String.format("MiddlewareComponent #%d initialised.", componentId));
    }

}
