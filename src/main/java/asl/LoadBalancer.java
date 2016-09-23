package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.List;

/**
 * This is the class that takes all incoming requests, hashes them and forwards to the correct MiddlewareComponent(s).
 */
public class LoadBalancer extends Thread {

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

    /**
     * Find if the request was a get, set or delete request.
     */
    public static RequestType getRequestType(String message) {
        String firstThreeChars = message.substring(0, 3);

        if(firstThreeChars.equals("set")) {
            return RequestType.SET;
        } else if(firstThreeChars.equals("get")) {
            return RequestType.GET;
        } else if(firstThreeChars.equals("del")) {
            return RequestType.DELETE;
        }

        return RequestType.OTHER;
    }

}
