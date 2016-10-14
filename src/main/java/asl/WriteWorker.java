package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.logging.log4j.core.layout.StringBuilderEncoder;

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
    private Map<Integer, Queue<Request>> inQueues;
    private Map<Integer, ByteBuffer> inBuffers;
    private List<SocketChannel> serverSocketChannels;
    private Map<Integer, SelectionKey> selectionKeys;
    private Map<Request, Integer> numResponses;
    private Selector selector;

    WriteWorker(Integer componentId, List<Integer> targetMachines, BlockingQueue<Request> writeQueue) {
        this.componentId = componentId;
        this.targetMachines = targetMachines;
        this.writeQueue = writeQueue;
        this.inQueues = new HashMap<>();
        this.inBuffers = new HashMap<>();
        this.selectionKeys = new HashMap<>();
        this.numResponses = new HashMap<>();
        this.serverSocketChannels = new ArrayList<>();


        try {
            this.selector = Selector.open();

            for (Integer targetMachine : targetMachines) {
                inQueues.put(targetMachine, new LinkedList<Request>());

                String addressString = MiddlewareMain.memcachedAddresses.get(targetMachine);
                String[] parts = addressString.split(":");
                String address = parts[0];
                Integer port = Integer.parseInt(parts[1]);
                InetSocketAddress inetSocketAddress = new InetSocketAddress(address, port);

                SocketChannel socketChannel = SocketChannel.open(inetSocketAddress);
                serverSocketChannels.add(socketChannel);
                socketChannel.configureBlocking(false);

                int ops = SelectionKey.OP_WRITE;
                SelectionKey selectionKey = socketChannel.register(selector, ops, targetMachine);
                selectionKeys.put(targetMachine, selectionKey);
                this.inBuffers.put(targetMachine, ByteBuffer.allocate(MiddlewareMain.RESPONSE_BUFFER_SIZE));
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

                int numElements = writeQueue.size();
                if(System.currentTimeMillis() % 1000 == 0 || numElements > 0) {
                    //log.info("queue has elements: " + numElements);
                }

                // region Take new element from write queue
                if (!writeQueue.isEmpty()) {
                    log.info("Writequeue has " + writeQueue.size() + " elements.");
                    Request r = writeQueue.remove();
                    log.info(String.format("Took %s from queue...", r));
                    r.setTimeDequeued();
                    log.debug(getName() + " processing request " + r);

                    for(Integer targetMachine : targetMachines) {

                        SelectionKey myKey = selectionKeys.get(targetMachine);
                        myKey.interestOps(SelectionKey.OP_WRITE);

                        SocketChannel socketChannel = (SocketChannel) myKey.channel();
                        log.debug(String.format("Server %d is writable.", targetMachine));

                        ByteBuffer buffer = r.getBuffer();
                        buffer.rewind();
                        while(buffer.hasRemaining()) {
                            socketChannel.write(buffer);
                        }

                        myKey.interestOps(SelectionKey.OP_READ);
                        inQueues.get(targetMachine).add(r);
                    }
                    r.setTimeForwarded();

                    numResponses.put(r, 0);
                }
                // endregion


                // region Communicate with memcached servers
                selector.select();
                Set<SelectionKey> selectedKeys = selector.selectedKeys();
                Iterator<SelectionKey> selectionKeyIterator = selectedKeys.iterator();

                while (selectionKeyIterator.hasNext()) {
                    SelectionKey myKey = selectionKeyIterator.next();
                    Integer targetMachine = (Integer) myKey.attachment();

                    /*if (myKey.isValid() && myKey.isWritable() && outQueues.get(targetMachine).size() > 0) {
                        /*SocketChannel socketChannel = (SocketChannel) myKey.channel();
                        Request r = outQueues.get(targetMachine).remove();
                        inQueues.get(targetMachine).add(r);
                        log.debug(String.format("Server %d is writable.", targetMachine));

                        ByteBuffer buffer = r.getBuffer();
                        buffer.rewind();
                        while(buffer.hasRemaining()) {
                            socketChannel.write(buffer);
                        }

                        r.setTimeForwarded();  // This will have the value of the latest write
                        socketChannel.register(selector, SelectionKey.OP_READ, targetMachine);

                    } else*/
                    if (myKey.isValid() && myKey.isReadable() && inQueues.get(targetMachine).size() > 0) {
                        log.debug(String.format("Server %d is readable.", targetMachine));
                        SocketChannel socketChannel = (SocketChannel) myKey.channel();

                        ByteBuffer buffer = inBuffers.get(targetMachine);
                        int read = socketChannel.read(buffer);

                        if(read > 0 || inBuffers.get(targetMachine).position() > 0) {
                            Integer firstLimit = Request.firstGetResponseLimit(buffer);
                            if (firstLimit == 0) {
                                continue;
                            } else {
                                Request r = inQueues.get(targetMachine).remove();
                                Integer currentPosition = buffer.position();
                                log.warn(String.format("Buffer position %d, limit %d, first request ends at %d.",
                                        currentPosition, buffer.limit(), firstLimit));

                                // Copy the first request from one buffer to the other
                                byte[] array = new byte[firstLimit];
                                for(int i=0; i<firstLimit; i++) {
                                    array[i] = buffer.get(i);
                                }
                                log.warn(String.format("Buffer: %s [len %d]",
                                        Util.getNonemptyString(buffer), Util.getNonemptyString(buffer).length()));
                                ByteBuffer responseBuffer = ByteBuffer.wrap(array);
                                Integer numExtraBytes = buffer.position() - firstLimit;
                                Util.copyToBeginning(buffer, firstLimit, numExtraBytes);
                                buffer.position(numExtraBytes);
                                log.warn(String.format("Buffer now: %s [len %d]",
                                        Util.getNonemptyString(buffer), Util.getNonemptyString(buffer).length()));
                                log.warn(String.format("Buffer position now %d, limit %d.",
                                        buffer.position(), buffer.limit()));
                                ResponseFlag responseFlag = Request.getResponseFlag(responseBuffer);
                                log.debug(String.format("Response flag from server %d: %s.", targetMachine, responseFlag));
                                if(responseFlag == ResponseFlag.UNKNOWN) {
                                    log.warn(String.format("Unknown response to %s: %s", r, Util.getNonemptyString(responseBuffer)));
                                }

                                // Keep the worst response
                                if(r.getResponseFlag() == ResponseFlag.NA || r.getResponseFlag() == ResponseFlag.STORED) {
                                    r.setResponseFlag(responseFlag);
                                    r.setResponseBuffer(responseBuffer);
                                }
                                numResponses.put(r, numResponses.get(r) + 1);

                                // If we've collected all responses
                                if(numResponses.get(r) == targetMachines.size()) {
                                    log.debug("Collected all responses to request " + r + "");
                                    r.respond();
                                    numResponses.remove(r);
                                }
                            }
                        }
                    }
                }
                // endregion
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
