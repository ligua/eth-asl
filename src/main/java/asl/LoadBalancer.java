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

    private long readRequestCounter;
    private long writeRequestCounter;

    private List<MiddlewareComponent> middlewareComponents;
    private Hasher hasher;
    private String address;
    private Integer port;

    private Map<SelectionKey, ByteBuffer> requestMessageBuffer2;
    private Map<SelectionKey, Integer> numBytesRead;
    private Map<SelectionKey, Request> keyToRequest;

    LoadBalancer(List<MiddlewareComponent> middlewareComponents, Hasher hasher, String address, Integer port) {
        this.middlewareComponents = middlewareComponents;
        this.hasher = hasher;
        this.address = address;
        this.port = port;
        this.requestMessageBuffer2 = new HashMap<>();
        this.numBytesRead = new HashMap<>();
        this.keyToRequest = new HashMap<>();
        this.readRequestCounter = 0;
        this.writeRequestCounter = 0;
    }

    /**
     * Take one request and add it to the correct queue.
     */
    void handleRequest(Request request, SelectionKey selectionKey) {
        keyToRequest.put(selectionKey, request);
        selectionKey.interestOps(SelectionKey.OP_WRITE);

        requestMessageBuffer2.remove(selectionKey);

        Integer primaryMachine = hasher.getPrimaryMachine(request.getKey());
        MiddlewareComponent mc = middlewareComponents.get(primaryMachine);

        ByteBuffer buffer = request.getBuffer();
        log.debug(String.format("Setting buffer limit from %d to %d.", buffer.limit(), numBytesRead.get(selectionKey)));
        buffer.limit(numBytesRead.get(selectionKey));
        numBytesRead.remove(selectionKey);

        log.debug("Sending request " + request + " to its primary machine #" + primaryMachine + ".");

        request.setTimeEnqueued();
        if(request.getType().equals(RequestType.GET)) {
            if(readRequestCounter % Request.LOG_SAMPLING_FREQUENCY == 0) {
                request.setShouldLog(true);
            }
            mc.readQueue.add(request);
            readRequestCounter++;
        } else {
            if(writeRequestCounter % Request.LOG_SAMPLING_FREQUENCY == 0) {
                request.setShouldLog(true);
            }
            mc.writeQueue.add(request);
            writeRequestCounter++;
        }

        if((readRequestCounter + writeRequestCounter) % INFO_EVERY_N_REQUESTS == 0) {
            log.info(String.format("Processed %5d reads and %5d writes so far.", readRequestCounter, writeRequestCounter));
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
                //log.debug("Waiting for a new connection...");
                // Select a set of keys whose corresponding channels are ready for I/O operations
                selector.select();

                // Token representing the registration of a SelectableChannel with a Selector
                Set<SelectionKey> selectedKeys = selector.selectedKeys();
                Iterator<SelectionKey> selectionKeyIterator = selectedKeys.iterator();

                //log.debug("Read queue 0 has " + middlewareComponents.get(0).readQueue.size() + " elements.");
                //log.debug("Write queue 0 has " + middlewareComponents.get(0).writeQueue.size() + " elements.");

                while (selectionKeyIterator.hasNext()) {
                    SelectionKey myKey = selectionKeyIterator.next();

                    if(keyToRequest.containsKey(myKey) && keyToRequest.get(myKey).hasResponse()) {
                        // If request has response, then write it.
                        Request r = keyToRequest.get(myKey);

                        ByteBuffer responseBuffer = r.getResponseBuffer();
                        keyToRequest.remove(myKey);

                        SocketChannel client = (SocketChannel) myKey.channel();

                        log.debug(String.format("Responding to request %s, response '%s', #bytes %d, first line '%s'.",
                                r,
                                Util.unEscapeString(Util.getNonemptyString(responseBuffer)),
                                Util.getNumNonemptyBytes(r.getResponseBuffer()),
                                Util.getFirstLine(r.getResponseBuffer())));

                        if(Request.isGetMiss(r.getResponseBuffer())) {
                            log.warn("GET miss! " + r);
                        }

                        // Write buffer
                        responseBuffer.rewind();
                        log.debug(String.format("Writing buffer. Position %d, #remaining bytes %d.",
                                responseBuffer.position(), responseBuffer.remaining()));
                        int bytesWritten = 0;
                        while(responseBuffer.hasRemaining()) {
                            int written = client.write(responseBuffer);
                            bytesWritten += written;
                        }
                        log.debug(String.format("Wrote %d bytes.", bytesWritten));

                        r.setTimeReturned();
                        r.logTimestamps();

                        myKey.interestOps(SelectionKey.OP_READ);
                    }

                    if ((myKey.isValid() && myKey.isAcceptable())) {
                        // If this key's channel is ready to accept a new socket connection
                        SocketChannel client = serverSocketChannel.accept();

                        // Adjusts this channel's blocking mode to false
                        client.configureBlocking(false);

                        // Operation-set bit for read operations
                        client.register(selector, SelectionKey.OP_READ);
                        //log.debug("Connection accepted: " + client.getLocalAddress());


                    } else if (myKey.isValid() && myKey.isReadable()) {
                        // If this key's channel is ready for reading

                        SocketChannel client = (SocketChannel) myKey.channel();

                        if(!requestMessageBuffer2.containsKey(myKey)) {
                            log.debug("SEEING KEY FOR FIRST TIME: " + myKey);

                            ByteBuffer buffer = ByteBuffer.allocate(MiddlewareMain.FULL_BUFFER_SIZE);
                            int read = client.read(buffer);
                            numBytesRead.put(myKey, read);

                            // If this is the first time we hear from this connection
                            if(buffer.position() == 0) {
                                client.close();         // TODO not sure if this is correct behaviour
                                continue;
                            }
                            RequestType requestType = Request.getRequestType(buffer);

                            //log.debug("request type: " + requestType);

                            if (requestType == RequestType.GET) {
                                // TODO assuming we get the whole GET or DELETE message in one chunk
                                Request r = new Request(buffer, client);

                                handleRequest(r, myKey);
                            } else if (requestType == RequestType.SET) {
                                // We may need to wait for the second line in the SET request.
                                requestMessageBuffer2.put(myKey, buffer);
                                //log.debug("Got a part of SET request [" + Util.unEscapeString(message) + "], waiting for more.");
                            }
                        } else {
                            log.debug("ADDING STUFF TO KEY: " + myKey);
                            // If we have something already from this connection
                            ByteBuffer buffer = requestMessageBuffer2.get(myKey);
                            int read = client.read(buffer);
                            numBytesRead.put(myKey, numBytesRead.get(myKey) + read);
                        }

                        // If we already have the whole message, we can create a Request.
                        if(requestMessageBuffer2.containsKey(myKey) &&
                                Request.isCompleteSetRequest(requestMessageBuffer2.get(myKey))) {
                            log.debug("KEY IS COMPLETE: " + myKey);
                            Request r = new Request(requestMessageBuffer2.get(myKey), client);
                            handleRequest(r, myKey);
                        }

                    }
                    selectionKeyIterator.remove();
                }
            }

        } catch (Exception ex) {
            log.error("an exception: ", ex);
            throw new RuntimeException(ex);
        }
    }

}
