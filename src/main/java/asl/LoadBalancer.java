package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.List;

/**
 * This is the class that takes all incoming requests, hashes them and forwards to the correct MiddlewareComponent(s).
 */
public class LoadBalancer {

    private static final Logger log = LogManager.getLogger(LoadBalancer.class);

    List<MiddlewareComponent> middlewareComponents;
    ConsistentHasher hasher;

    LoadBalancer(List<MiddlewareComponent> middlewareComponents, ConsistentHasher hasher) {
        this.middlewareComponents = middlewareComponents;
        this.hasher = hasher;

        log.info("Load balancer initialised.");
    }

    void handleWriteRequest() {

    }

    void handleReadRequest() {

    }

}
