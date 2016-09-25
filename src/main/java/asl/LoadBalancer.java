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

    void handleWriteRequest(Request request) {
        // TODO send the request to appropriate machine
    }

    void handleReadRequest(Request request) {
        Integer primaryMachine = hasher.getPrimaryMachine(request.key);
        // TODO send request to appropriate machine

    }

    @Override
    public void run() {
        // TODO
    }

}
