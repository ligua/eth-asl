package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.nio.channels.ServerSocketChannel;
import java.nio.channels.SocketChannel;
import java.util.*;

/**
 * This is the class that takes all incoming requests, hashes them and forwards to the correct MiddlewareComponent(s).
 */
public class LoadBalancer implements Runnable {

    private static final Logger log = LogManager.getLogger(LoadBalancer.class);
    private static final String address = "localhost";
    private static final Integer port = 11212;
    private static final Integer LOG_EVERY_N_REQUESTS = 1;

    private Integer requestCounter;

    private List<MiddlewareComponent> middlewareComponents;
    private Hasher hasher;

    private Map<SelectionKey, String> requestMessageBuffer;

    LoadBalancer(List<MiddlewareComponent> middlewareComponents, Hasher hasher) {
        this.middlewareComponents = middlewareComponents;
        this.hasher = hasher;
        this.requestMessageBuffer = new HashMap<>();
        this.requestCounter = 0;
    }

    /**
     * Take one request and add it to the correct queue.
     */
    void handleRequest(Request request) {
        Integer primaryMachine = hasher.getPrimaryMachine(request.getKey());
        MiddlewareComponent mc = middlewareComponents.get(primaryMachine);

        log.debug("Sending request " + request + " to its primary machine #" + primaryMachine + ".");

        if(request.getType().equals(RequestType.GET)) {
            mc.readQueue.add(request);
        } else {
            mc.writeQueue.add(request);     // DELETE requests also go to the write queue.
        }

        requestCounter++;
        if(requestCounter > 0 && requestCounter % LOG_EVERY_N_REQUESTS == 0) {
            log.info(String.format("Processed %5d requests so far.", requestCounter));
        }
    }

    @Override
    public void run() {

        log.info("Load balancer started.");

        try {
            // Selector: multiplexor of SelectableChannel objects
            Selector selector = Selector.open(); // selector is open here

            // ServerSocketChannel: selectable channel for stream-oriented listening sockets
            ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
            InetSocketAddress inetSocketAddress = new InetSocketAddress(address, port);

            // Binds the channel's socket to a local address and configures the socket to listen for connections
            serverSocketChannel.bind(inetSocketAddress);

            // Adjusts this channel's blocking mode.
            serverSocketChannel.configureBlocking(false);

            int ops = serverSocketChannel.validOps();
            SelectionKey selectionKey = serverSocketChannel.register(selector, ops, null);

            while(true) {
                log.debug("Waiting for a new connection...");
                // Select a set of keys whose corresponding channels are ready for I/O operations
                selector.select();

                // Token representing the registration of a SelectableChannel with a Selector
                Set<SelectionKey> selectedKeys = selector.selectedKeys();
                Iterator<SelectionKey> selectionKeyIterator = selectedKeys.iterator();


                while (selectionKeyIterator.hasNext()) {
                    SelectionKey myKey = selectionKeyIterator.next();

                    if ((myKey.isValid() && myKey.isAcceptable())) {
                        // If this key's channel is ready to accept a new socket connection
                        SocketChannel client = serverSocketChannel.accept();

                        // Adjusts this channel's blocking mode to false
                        client.configureBlocking(false);

                        // Operation-set bit for read operations
                        client.register(selector, SelectionKey.OP_READ);
                        log.debug("Connection accepted: " + client.getLocalAddress());


                    } else if (myKey.isValid() && myKey.isReadable()) {
                        // If this key's channel is ready for reading

                        SocketChannel client = (SocketChannel) myKey.channel();
                        ByteBuffer buffer = ByteBuffer.allocate(256);           // TODO is this enough?
                        client.read(buffer);
                        String message = new String(buffer.array());
                        message = message.substring(0, buffer.position());

                        if(!requestMessageBuffer.containsKey(myKey)) {
                            log.debug("SEEING KEY FOR FIRST TIME: " + myKey);
                            // If this is the first time we hear from this connection
                            RequestType requestType = Request.getRequestType(message);

                            if (requestType == RequestType.GET || requestType == RequestType.DELETE) {
                                // TODO assuming we get the whole GET or DELETE message in one chunk
                                Request r = new Request(message, client);
                                log.debug(r.getType() + " message received: " + r);

                                myKey.interestOps(SelectionKey.OP_WRITE); // TODO
                                handleRequest(r);
                            } else if (requestType == RequestType.SET) {
                                // We may need to wait for the second line in the SET request.
                                requestMessageBuffer.put(myKey, message);
                                //log.debug("Got a part of SET request [" + Util.unEscapeString(message) + "], waiting for more.");
                            }
                        } else {
                            log.debug("ADDING STUFF TO KEY: " + myKey);
                            // If we have something already from this connection
                            String updatedMessage = requestMessageBuffer.get(myKey) + message;
                            requestMessageBuffer.put(myKey, updatedMessage);
                        }

                        // If we already have the whole message, we can create a Request.
                        if(requestMessageBuffer.containsKey(myKey) &&
                                Request.isCompleteSetRequest(requestMessageBuffer.get(myKey))) {
                            log.debug("KEY IS COMPLETE: " + myKey);
                            String fullMessage = requestMessageBuffer.get(myKey);
                            requestMessageBuffer.remove(myKey);
                            Request r = new Request(fullMessage, client);
                            log.debug(r.getType() + " message received: " + r);
                            myKey.interestOps(SelectionKey.OP_WRITE); // TODO
                            handleRequest(r);
                        }

                    }
                    selectionKeyIterator.remove();
                }
            }

        } catch (Exception ex) {
            log.error(ex);
            throw new RuntimeException(ex);
        }
    }

}
