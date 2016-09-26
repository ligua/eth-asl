package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.List;
import java.util.Queue;

/**
 * This class is responsible for writing values to memcached and returning responses to the client.
 */
class WriteWorker implements Runnable {

    private static final Logger log = LogManager.getLogger(WriteWorker.class);

    private Integer componentId;
    private List<Integer> targetMachines;

    WriteWorker(Integer componentId, List<Integer> targetMachines, Queue<Request> writeQueue) {
        this.componentId = componentId;
        this.targetMachines = targetMachines;

        // TODO start connections to all memcached servers using MemcachedConnection
        // TODO




    }

    @Override
    public void run() {
        log.info(String.format("%s Component #%d WriteWorker initialised; writing to machines: %s.",
                getName(), componentId, Util.collectionToString(targetMachines)));

        // TODO start taking stuff from queue and executing it
    }

    public String getName() {
        return String.format("c%dw0", componentId);
    }
}
