package ch.ethz.systems.asl;

import java.util.ArrayList;
import java.util.List;

/**
 * The class responsible for setting up and connecting everything in the middleware.
 * This will be run as the main class of the middleware.
 */
public class MiddlewareMain {

    Integer numMemcachedServers;            // N
    Integer numReadThreadsPerServer;        // T
    Integer replicationFactor;              // R

    ConsistentHasher hasher;

    List<MiddlewareComponent> components;

    LoadBalancer loadBalancer;

    MiddlewareMain() {
        this(1, 1, 1);
    }

    MiddlewareMain(Integer numMemcachedServers, Integer numReadThreadsPerServer, Integer replicationFactor) {
        this.numMemcachedServers = numMemcachedServers;
        this.numReadThreadsPerServer = numReadThreadsPerServer;
        this.replicationFactor = replicationFactor;

        this.hasher = new ConsistentHasherImpl(numMemcachedServers, replicationFactor);

        // Create all middleware components
        this.components = new ArrayList<>();
        for(int id=0; id<numMemcachedServers; id++) {
            components.add(new MiddlewareComponent(id));
        }

        // Create load balancer
        loadBalancer = new LoadBalancer(components, hasher);
    }

    public static void main(String[] args) {

        MiddlewareMain mwm = new MiddlewareMain();

    }

}
