package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.nio.channels.ServerSocketChannel;
import java.nio.channels.SocketChannel;
import java.util.Iterator;
import java.util.List;
import java.util.Set;

/**
 * This is the class that takes all incoming requests, hashes them and forwards to the correct MiddlewareComponent(s).
 */
public class LoadBalancer implements Runnable {

    private static final Logger log = LogManager.getLogger(LoadBalancer.class);
    private static final String address = "localhost";
    private static final Integer port = 11212;

    private List<MiddlewareComponent> middlewareComponents;
    private Hasher hasher;

    LoadBalancer(List<MiddlewareComponent> middlewareComponents, Hasher hasher) {
        this.middlewareComponents = middlewareComponents;
        this.hasher = hasher;

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
                log.info("Waiting for a new connection...");
                // Select a set of keys whose corresponding channels are ready for I/O operations
                selector.select();

                // Token representing the registration of a SelectableChannel with a Selector
                Set<SelectionKey> selectedKeys = selector.selectedKeys();
                Iterator<SelectionKey> selectionKeyIterator = selectedKeys.iterator();


                while (selectionKeyIterator.hasNext()) {
                    SelectionKey myKey = selectionKeyIterator.next();

                    if (myKey.isAcceptable()) {
                        // If this key's channel is ready to accept a new socket connection
                        SocketChannel client = serverSocketChannel.accept();

                        // Adjusts this channel's blocking mode to false
                        client.configureBlocking(false);

                        // Operation-set bit for read operations
                        client.register(selector, SelectionKey.OP_READ);
                        log.info("Connection accepted: " + client.getLocalAddress());


                    } else if (myKey.isReadable()) {
                        // If this key's channel is ready for reading

                        SocketChannel client = (SocketChannel) myKey.channel();
                        ByteBuffer buffer = ByteBuffer.allocate(256);
                        client.read(buffer);
                        String message = new String(buffer.array()).trim();

                        RequestType requestType = Request.getRequestType(message);
                        log.debug(requestType + " message received: " + message);
                        if(requestType == RequestType.GET || requestType == RequestType.SET || requestType == RequestType.DELETE) {
                            Request r = new Request(message, client);
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
