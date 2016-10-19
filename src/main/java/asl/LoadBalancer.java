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
    private static final Integer INFO_EVERY_N_REQUESTS = 1000;
    public static final Integer SELECTOR_TIMEOUT = 1; // milliseconds

    private long readRequestCounter;
    private long writeRequestCounter;

    private List<MiddlewareComponent> middlewareComponents;
    private Hasher hasher;
    private String address;
    private Integer port;

    private Map<SelectionKey, ByteBuffer> requestMessageBuffer;
    private Map<SelectionKey, Integer> numBytesRead;

    LoadBalancer(List<MiddlewareComponent> middlewareComponents, Hasher hasher, String address, Integer port) {
        this.middlewareComponents = middlewareComponents;
        this.hasher = hasher;
        this.address = address;
        this.port = port;
        this.requestMessageBuffer = new HashMap<>();
        this.numBytesRead = new HashMap<>();
        this.readRequestCounter = 0;
        this.writeRequestCounter = 0;
    }

    /**
     * Take one request and add it to the correct queue.
     */
    private void handleRequest(Request request, SelectionKey selectionKey) {
        selectionKey.interestOps(SelectionKey.OP_WRITE);

        requestMessageBuffer.remove(selectionKey);

        Integer primaryMachine = hasher.getPrimaryMachine(request.getKey());
        MiddlewareComponent mc = middlewareComponents.get(primaryMachine);

        ByteBuffer buffer = request.getBuffer();
        buffer.limit(numBytesRead.get(selectionKey));
        numBytesRead.remove(selectionKey);

        //log.debug(String.format("Sending request %s to its primary machine #%d.", request, primaryMachine));

        if(request.getType().equals(RequestType.GET)) {
            if(readRequestCounter % Request.LOG_SAMPLING_FREQUENCY == 0) {
                request.setShouldLog(true);
            }
            request.setTimeEnqueued();
            mc.readQueue.add(request);
            readRequestCounter++;
        } else {
            if(writeRequestCounter % Request.LOG_SAMPLING_FREQUENCY == 0) {
                request.setShouldLog(true);
            }
            request.setTimeEnqueued();
            mc.writeQueue.add(request);
            writeRequestCounter++;
        }

        if((readRequestCounter + writeRequestCounter) % INFO_EVERY_N_REQUESTS == 0) {
            log.info(String.format("Processed %6d reads and %6d writes so far.", readRequestCounter, writeRequestCounter));
        }
    }

    @Override
    public void run() {

        log.info("Load balancer started.");

        try {
            Selector selector = Selector.open();

            // ServerSocketChannel: selectable channel for stream-oriented listening sockets
            ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
            InetSocketAddress inetSocketAddress = new InetSocketAddress(address, port);

            serverSocketChannel.bind(inetSocketAddress);

            serverSocketChannel.configureBlocking(false);

            int ops = serverSocketChannel.validOps();
            SelectionKey selectionKey = serverSocketChannel.register(selector, ops, null);

            while(true) {
                selector.select(SELECTOR_TIMEOUT);

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

                    } else if (myKey.isValid() && myKey.isReadable()) {
                        // If this key's channel is ready for reading

                        SocketChannel client = (SocketChannel) myKey.channel();

                        if(!requestMessageBuffer.containsKey(myKey)) {
                            // If this is the first time we hear from this connection
                            //log.debug("SEEING KEY FOR FIRST TIME: " + myKey);

                            ByteBuffer buffer = ByteBuffer.allocate(MiddlewareMain.FULL_BUFFER_SIZE);
                            int read = client.read(buffer);
                            numBytesRead.put(myKey, read);

                            // If we read nothing
                            if(read == 0) { // TODO change to read == 0
                                client.close();         // TODO not sure if this is correct behaviour
                                continue;
                            }
                            RequestType requestType = Request.getRequestType(buffer);

                            if (requestType == RequestType.GET ||requestType == RequestType.DELETE) {
                                Request r = new Request(buffer, myKey);

                                handleRequest(r, myKey);
                            } else if (requestType == RequestType.SET) {
                                // We may need to wait for the second line in the SET request.
                                requestMessageBuffer.put(myKey, buffer);
                            }
                        } else {
                            //log.debug("ADDING STUFF TO KEY: " + myKey);
                            // If we have something already from this connection
                            ByteBuffer buffer = requestMessageBuffer.get(myKey);
                            int read = client.read(buffer);
                            numBytesRead.put(myKey, numBytesRead.get(myKey) + read);
                        }

                        // If we already have the whole message, we can create a Request.
                        if(requestMessageBuffer.containsKey(myKey) &&
                                Request.isCompleteSetRequest(requestMessageBuffer.get(myKey))) {
                            //log.debug("KEY IS COMPLETE: " + myKey);
                            Request r = new Request(requestMessageBuffer.get(myKey), myKey);
                            handleRequest(r, myKey);
                        }

                    }
                    selectionKeyIterator.remove();
                }
            }

        } catch (Exception ex) {
            log.error("Exception: ", ex);
            throw new RuntimeException(ex);
        }
    }

}
