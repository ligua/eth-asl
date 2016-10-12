package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.channels.SocketChannel;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;
import java.util.Queue;
import java.util.concurrent.BlockingQueue;

/**
 * This class is responsible for writing values to memcached and returning responses to the client.
 */
class WriteWorker implements Runnable {

    private static final Logger log = LogManager.getLogger(WriteWorker.class);

    private Integer componentId;
    private List<Integer> targetMachines;
    private BlockingQueue<Request> writeQueue;
    private List<Queue<Request>> serverQueues;
    private List<SocketChannel> serverSockets;

    WriteWorker(Integer componentId, List<Integer> targetMachines, BlockingQueue<Request> writeQueue) {
        this.componentId = componentId;
        this.targetMachines = targetMachines;
        this.writeQueue = writeQueue;
        this.serverQueues = new ArrayList<>();
        this.serverSockets = new ArrayList<>();

        try {
            for (Integer targetMachine : targetMachines) {
                serverQueues.add(new LinkedList<Request>());

                // TODO open connection to memcached server
                String addressString = MiddlewareMain.memcachedAddresses.get(targetMachine);
                String[] parts = addressString.split(":");
                String address = parts[0];
                Integer port = Integer.parseInt(parts[1]);
                InetSocketAddress inetSocketAddress = new InetSocketAddress(address, port);

                SocketChannel socketChannel = SocketChannel.open(inetSocketAddress);
                socketChannel.configureBlocking(false);

                this.serverSockets.add(socketChannel);
            }

            // Wait for connection to all servers to finish
            List<SocketChannel> notFinishedYet = new ArrayList<>(serverSockets);
            while (notFinishedYet.size() > 0) {
                for(SocketChannel socketChannel : notFinishedYet) {
                    if (socketChannel.finishConnect()) {
                        notFinishedYet.remove(socketChannel);
                    }
                }
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
                serverSockets.get(0);

                if (!writeQueue.isEmpty()) {
                    Request r = writeQueue.take();
                    r.setTimeDequeued();
                    log.debug(getName() + " processing request " + r);

                    for(Integer targetMachine : targetMachines) {
                        SocketChannel socketChannel = serverSockets.get(targetMachine);
                        ByteBuffer buffer = r.getBuffer();
                        while(buffer.hasRemaining()) {
                            socketChannel.write(buffer);
                        }
                        buffer.position(0);

                    }

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
