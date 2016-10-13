package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.nio.channels.SocketChannel;
import java.util.*;
import java.util.concurrent.BlockingQueue;

/**
 * This class is responsible for writing values to memcached and returning responses to the client.
 */
class WriteWorker implements Runnable {

    private static final Logger log = LogManager.getLogger(WriteWorker.class);

    private Integer componentId;
    private List<Integer> targetMachines;
    private BlockingQueue<Request> writeQueue;
    private Map<Integer, Queue<Request>> outQueues;
    private Map<Integer, Queue<Request>> inQueues;
    private List<SocketChannel> serverSocketChannels;
    private Map<Request, Integer> numResponses;
    private Selector selector;

    WriteWorker(Integer componentId, List<Integer> targetMachines, BlockingQueue<Request> writeQueue) {
        this.componentId = componentId;
        this.targetMachines = targetMachines;
        this.writeQueue = writeQueue;
        this.outQueues = new HashMap<>();
        this.inQueues = new HashMap<>();
        this.numResponses = new HashMap<>();
        this.serverSocketChannels = new ArrayList<>();


        try {
            this.selector = Selector.open();

            for (Integer targetMachine : targetMachines) {
                outQueues.put(targetMachine, new LinkedList<Request>());
                inQueues.put(targetMachine, new LinkedList<Request>());

                // TODO open connection to memcached server
                String addressString = MiddlewareMain.memcachedAddresses.get(targetMachine);
                String[] parts = addressString.split(":");
                String address = parts[0];
                Integer port = Integer.parseInt(parts[1]);
                InetSocketAddress inetSocketAddress = new InetSocketAddress(address, port);

                SocketChannel socketChannel = SocketChannel.open(inetSocketAddress);
                serverSocketChannels.add(socketChannel);
                socketChannel.configureBlocking(false);

                int ops = SelectionKey.OP_WRITE;
                SelectionKey selectionKey = socketChannel.register(selector, ops, targetMachine); // TODO targetMachine is the extra payload (attachment)
            }

            // Wait for connection to all servers to finish
            List<SocketChannel> notFinishedYet = new ArrayList<>(serverSocketChannels);
            while (notFinishedYet.size() > 0) {
                List<SocketChannel> toRemove = new ArrayList<>();
                for(SocketChannel socketChannel : notFinishedYet) {
                    if (socketChannel.finishConnect()) {
                        log.info(String.format("%s connected to server %s.", getName(), socketChannel.getRemoteAddress()));
                        toRemove.add(socketChannel);
                    }
                }
                notFinishedYet.removeAll(toRemove);
            }



        } catch (Exception ex) {
            log.error(ex);
            throw new RuntimeException(ex);
        }
    }

    @Override
    public void run() {
        try {
            log.info(String.format("%s started; writing to machines: %s.", getName(), Util.collectionToString(targetMachines)));

            while (true) {
                selector.select();
                Set<SelectionKey> selectedKeys = selector.selectedKeys();
                Iterator<SelectionKey> selectionKeyIterator = selectedKeys.iterator();

                while (selectionKeyIterator.hasNext()) {
                    SelectionKey myKey = selectionKeyIterator.next();
                    Integer targetMachine = (Integer) myKey.attachment();

                    //log.debug(String.format("Server %d.", targetMachine));

                    if (myKey.isValid() && myKey.isWritable() && outQueues.get(targetMachine).size() > 0) {
                        log.debug(String.format("Server %d is writable.", targetMachine));
                        SocketChannel socketChannel = (SocketChannel) myKey.channel();
                        Request r = outQueues.get(targetMachine).remove();
                        inQueues.get(targetMachine).add(r);

                        ByteBuffer buffer = r.getBuffer();
                        while(buffer.hasRemaining()) {
                            socketChannel.write(buffer);
                        }
                        r.setTimeForwarded();  // This will have the value of the latest write
                        socketChannel.register(selector, SelectionKey.OP_READ, targetMachine);
                        buffer.rewind();  // TODO not sure if this resets everything properly

                    } else if (myKey.isValid() && myKey.isReadable()  && inQueues.get(targetMachine).size() > 0) {
                        log.debug(String.format("Server %d is readable.", targetMachine));
                        SocketChannel socketChannel = (SocketChannel) myKey.channel();
                        Request r = inQueues.get(targetMachine).remove();

                        ByteBuffer buffer = ByteBuffer.allocate(MiddlewareMain.RESPONSE_BUFFER_SIZE);
                        int readTotal = 0;
                        int read = socketChannel.read(buffer);

                        // If the message from memcached continued
                        while(read > 0) {  // TODO could also be 0 just temporarily b/c of network conditions or sth -- can cause problems!
                            readTotal += read;
                            read = socketChannel.read(buffer);
                        }
                        socketChannel.register(selector, SelectionKey.OP_WRITE, targetMachine);

                        ResponseFlag responseFlag = Request.getResponseFlag(buffer);
                        log.debug(String.format("Response flag from server %d: %s.", targetMachine, responseFlag));
                        // Keep the worst response
                        if(r.getResponseFlag() == ResponseFlag.NA || r.getResponseFlag() == ResponseFlag.STORED) {
                            r.setResponseFlag(responseFlag);
                            buffer.rewind();
                            r.setResponseBuffer(buffer);
                        }
                        numResponses.put(r, numResponses.get(r) + 1);

                        // If we've collected all responses
                        //log.debug(String.format("Have %d responses but %d machines.", numResponses.get(r), targetMachines.size()));
                        if(numResponses.get(r) == targetMachines.size()) {
                            log.debug("Collected all responses to request " + r + "");
                            r.respond();
                            numResponses.remove(r);
                        }

                    }

                }

                if (!writeQueue.isEmpty()) {
                    Request r = writeQueue.take();
                    r.setTimeDequeued();
                    log.debug(getName() + " processing request " + r);

                    for(Integer targetMachine : targetMachines) {
                        outQueues.get(targetMachine).add(r);
                    }

                    numResponses.put(r, 0);

                }
            }
        } catch (Exception ex) {
            log.error(ex);
            throw new RuntimeException(ex);
        }
    }

    public String getName() {
        return String.format("c%dw0", componentId);
    }
}
