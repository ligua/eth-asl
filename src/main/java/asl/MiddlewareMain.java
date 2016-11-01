package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * The class responsible for setting up and connecting everything in the middleware.
 * This will be run as the main class of the middleware.
 */
public class MiddlewareMain implements Runnable {

    private static final Logger log = LogManager.getLogger(MiddlewareMain.class);

    public static final Integer FULL_BUFFER_SIZE = 2048;
    public static final Integer RESPONSE_BUFFER_SIZE = 1024;
    public static final Integer QUEUE_SIZE = 200;
    public static final long WORKER_SLEEP_TIME = 1;  // ms

    public static List<String> memcachedAddresses;

    private String loadBalancerIp;
    private Integer loadBalancerPort;
    private Integer numMemcachedServers;            // N
    private Integer numReadThreadsPerServer;        // T
    private Integer replicationFactor;              // R

    private Hasher hasher;

    private List<MiddlewareComponent> components;

    private LoadBalancer loadBalancer;

    public MiddlewareMain() {
        this("localhost",
                11212,
                new ArrayList<String>(Arrays.asList("localhost:11211", "localhost:11210")),
                1,
                2);
    }

    MiddlewareMain(String loadBalancerIp, Integer loadBalancerPort, List<String> memcachedAddresses,
                           Integer numReadThreadsPerServer, Integer replicationFactor) {

        this.loadBalancerIp = loadBalancerIp;
        this.loadBalancerPort = loadBalancerPort;
        this.numMemcachedServers = memcachedAddresses.size();
        this.numReadThreadsPerServer = numReadThreadsPerServer;
        this.replicationFactor = replicationFactor;
        this.hasher = new UniformHasher(numMemcachedServers, replicationFactor);

        MiddlewareMain.memcachedAddresses = memcachedAddresses;
    }

    @Override
    public void run() {
        log.info("Starting middleware...");
        log.info("[load balancer IP]: " + loadBalancerIp);
        log.info("[load balancer port]: " + loadBalancerPort);
        log.info("[number of read threads per component]: " + numReadThreadsPerServer);
        log.info("[replication factor]: " + replicationFactor);
        log.info("[memcached addresses]: " + Arrays.toString(MiddlewareMain.memcachedAddresses.toArray()));

        ExecutorService executor = Executors.newFixedThreadPool(numMemcachedServers * (numReadThreadsPerServer + 1) + 1);

        // Create all middleware components
        this.components = new ArrayList<>();
        for(int id=0; id<numMemcachedServers; id++) {
            List<Integer> targetMachines = hasher.getTargetMachines(id);
            components.add(new MiddlewareComponent(id, numReadThreadsPerServer, targetMachines, executor));
        }

        // Create load balancer
        loadBalancer = new LoadBalancer(components, hasher, loadBalancerIp, loadBalancerPort);
        executor.submit(loadBalancer);

        log.info("Middleware initialised.");
    }

    public static void main(String[] args) {

        MiddlewareMain mwm = new MiddlewareMain();
        mwm.run();

    }

}
