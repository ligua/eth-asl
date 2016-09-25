package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.List;

/**
 * This is the class that takes all incoming requests, hashes them and forwards to the correct MiddlewareComponent(s).
 */
public class LoadBalancer implements Runnable {

    private static final Logger log = LogManager.getLogger(LoadBalancer.class);

    private List<MiddlewareComponent> middlewareComponents;
    private Hasher hasher;

    LoadBalancer(List<MiddlewareComponent> middlewareComponents, Hasher hasher) {
        this.middlewareComponents = middlewareComponents;
        this.hasher = hasher;

        log.info("Load balancer initialised.");
    }

    /**
     * Take one request and add it to the correct queue.
     */
    void handleRequest(Request request) {
        Integer primaryMachine = hasher.getPrimaryMachine(request.key);
        MiddlewareComponent mc = middlewareComponents.get(primaryMachine);

        if(request.type.equals(RequestType.GET)) {
            mc.readQueue.add(request);
        } else {
            mc.writeQueue.add(request);     // DELETE requests also go to the write queue.
        }
    }

    @Override
    public void run() {
        // TODO
    }

}
