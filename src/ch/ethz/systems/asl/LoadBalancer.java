package ch.ethz.systems.asl;

import java.util.List;

/**
 * This is the class that takes all incoming requests, hashes them and forwards to the correct MiddlewareComponent(s).
 */
public class LoadBalancer {

    List<MiddlewareComponent> middlewareComponents;
    ConsistentHasher hasher;

    LoadBalancer(List<MiddlewareComponent> middlewareComponents, ConsistentHasher hasher) {
        this.middlewareComponents = middlewareComponents;
        this.hasher = hasher;
    }

    void handleWriteRequest() {

    }

    void handleReadRequest() {

    }

}
