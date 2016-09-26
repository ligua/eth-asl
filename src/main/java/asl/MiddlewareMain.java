package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * The class responsible for setting up and connecting everything in the middleware.
 * This will be run as the main class of the middleware.
 */
public class MiddlewareMain {

    private static final Logger log = LogManager.getLogger(MiddlewareMain.class);

    private Integer numMemcachedServers;            // N
    private Integer numReadThreadsPerServer;        // T
    private Integer replicationFactor;              // R

    private Hasher hasher;

    private List<MiddlewareComponent> components;

    private LoadBalancer loadBalancer;

    public MiddlewareMain() {
        this(1, 1, 0);
    }

    private MiddlewareMain(Integer numMemcachedServers, Integer numReadThreadsPerServer, Integer replicationFactor) {
        log.info("Starting middleware...");
        this.numMemcachedServers = numMemcachedServers;
        this.numReadThreadsPerServer = numReadThreadsPerServer;
        this.replicationFactor = replicationFactor;

        this.hasher = new UniformHasher(numMemcachedServers, replicationFactor);

        // Create all middleware components
        this.components = new ArrayList<>();
        for(int id=0; id<numMemcachedServers; id++) {
            List<Integer> targetMachines = hasher.getTargetMachines(id);
            components.add(new MiddlewareComponent(id, numReadThreadsPerServer, targetMachines));
        }

        // Create load balancer
        loadBalancer = new LoadBalancer(components, hasher);
        ExecutorService executor = Executors.newCachedThreadPool();
        executor.submit(loadBalancer);

        log.info("Middleware initialised.");
    }

    public static void main(String[] args) {

        //MiddlewareMain mwm = new MiddlewareMain(3, 5, 2);
        MiddlewareMain mwm = new MiddlewareMain();

    }

}
