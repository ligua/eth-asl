package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

/**
 * The class responsible for queueing for one memcached instance.
 * In the example architecture, there are 3 of these.
 */
public class MiddlewareComponent {

    private static final Logger log = LogManager.getLogger(MiddlewareComponent.class);

    // TODO for read queues, use BlockingQueue

    MiddlewareComponent(Integer id) {




        log.info(String.format("MiddlewareComponent #%d initialised.", id));
    }

}
