package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.List;
import java.util.Queue;
import java.util.concurrent.BlockingQueue;

/**
 * This class is responsible for writing values to memcached and returning responses to the client.
 */
class WriteWorker implements Runnable {

    private static final Logger log = LogManager.getLogger(WriteWorker.class);

    private Integer componentId;
    private List<Integer> targetMachines;
    private BlockingQueue<Request> writeQueue;



    WriteWorker(Integer componentId, List<Integer> targetMachines, BlockingQueue<Request> writeQueue) {
        this.componentId = componentId;
        this.targetMachines = targetMachines;
        this.writeQueue = writeQueue;

        // TODO start connections to all memcached servers using MemcachedConnection
        // TODO




    }

    @Override
    public void run() {
        log.info(String.format("%s started; writing to machines: %s.", getName(), Util.collectionToString(targetMachines)));

        while(true) {
            if(!writeQueue.isEmpty()) {
                try {
                    Request r = writeQueue.take();
                    log.info(getName() + " processing request " + r);
                    // TODO actually do something with the request
                    
                } catch (InterruptedException ex) {
                    log.error(ex);
                }
            }
        }
    }

    public String getName() {
        return String.format("c%dw0", componentId);
    }
}
