package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
import java.io.InputStream;
import java.net.Socket;
import java.nio.channels.Channels;
import java.nio.channels.ClosedChannelException;
import java.nio.channels.WritableByteChannel;
import java.util.concurrent.BlockingQueue;

/**
 * This class is responsible for reading values from memcached and returning responses to the client.
 */
class ReadWorker implements Runnable {

    private Integer componentId;
    private Integer threadId;
    private BlockingQueue<Request> readQueue;
    //private MemcachedConnection connection;
    private Socket memcachedSocket;
    private WritableByteChannel channelOut;
    private InputStream streamIn;

    private static final Logger log = LogManager.getLogger(ReadWorker.class);

    ReadWorker(Integer componentId, Integer threadId, BlockingQueue<Request> readQueue) {
        this.componentId = componentId;
        this.threadId = threadId;
        this.readQueue = readQueue;

        // Setup connection to memcached
        String addressString = MiddlewareMain.memcachedAddresses.get(componentId);
        String[] parts = addressString.split(":");
        String address = parts[0];
        Integer port = Integer.parseInt(parts[1]);

        try {
            memcachedSocket = new Socket(address, port);
            channelOut = Channels.newChannel(memcachedSocket.getOutputStream());
            streamIn = this.memcachedSocket.getInputStream();
        } catch (IOException ex) {
            log.error(ex);
            throw new RuntimeException(ex);
        }

        //this.connection = new MemcachedConnection(componentId);
    }

    @Override
    public void run() {
        try {
            log.info(String.format("%s started.", getName()));

            while (true) {
                if (!readQueue.isEmpty()) {
                    try {
                        Request r = readQueue.take();
                        r.setTimeDequeued();
                        log.debug(getName() + " processing request " + r);

                        // Write request
                        channelOut.write(r.getBuffer());
                        r.setTimeForwarded();

                        // Read response
                        byte[] buffer = new byte[MiddlewareMain.BUFFER_SIZE]; // TODO use ByteBuffer here?
                        int readTotal = 0;
                        int read = streamIn.read(buffer);

                        // If the message from memcached continued
                        while(read != -1) {
                            readTotal += read;
                            if(streamIn.available() > 0) {      // TODO This is probably not a good way to do this?
                                read = streamIn.read(buffer);
                            } else {
                                read = -1;
                            }
                        }

                        String response = new String(buffer, 0, readTotal);
                        try {
                            r.respond(response);
                        } catch(ClosedChannelException ex) {
                            log.error("Could not respond to request " + r + ": " + ex);
                        }

                        log.debug("Got response to " + r + ".");
                    } catch (InterruptedException ex) {
                        log.error(ex);
                    }
                }
            }
        } catch(Exception ex) {
            log.error("Exception: ", ex);
            throw new RuntimeException(ex);
        }
    }

    public String getName() {
        return String.format("c%dr%d", componentId, threadId);
    }
}
