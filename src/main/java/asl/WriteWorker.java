package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.ArrayList;
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
    private List<MemcachedConnection> connections;

    WriteWorker(Integer componentId, List<Integer> targetMachines, BlockingQueue<Request> writeQueue) {
        this.componentId = componentId;
        this.targetMachines = targetMachines;
        this.writeQueue = writeQueue;

        connections = new ArrayList<>();
        for(Integer targetMachine : targetMachines) {
            // TODO initialise the connection smartly so that we actually connect to different machines based on number
            connections.add(new MemcachedConnection());
        }
    }

    @Override
    public void run() {
        try {
            log.info(String.format("%s started; writing to machines: %s.", getName(), Util.collectionToString(targetMachines)));

            while (true) {
                if (!writeQueue.isEmpty()) {
                    try {
                        Request r = writeQueue.take();
                        log.debug(getName() + " processing request " + r);

                        // Write to all secondary machines
                        for(MemcachedConnection mc : connections.subList(1, connections.size())) {
                            mc.sendRequest(r, false);
                        }

                        // Write to primary machine
                        connections.get(0).sendRequest(r);

                    } catch (InterruptedException ex) {
                        log.error(ex);
                    }
                }
            }
        } catch (Exception ex) {
            log.error(ex);
            throw new RuntimeException(ex);
        }
    }

    public String getName() {
        return String.format("c%dw0", componentId);
    }
}
