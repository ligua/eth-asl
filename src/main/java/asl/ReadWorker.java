package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
import java.io.InputStream;
import java.net.Socket;
import java.nio.ByteBuffer;
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
                        r.getBuffer().rewind();
                        channelOut.write(r.getBuffer()); // TODO maybe this doesn't get written? (or blocks until written?)
                        r.setTimeForwarded();

                        // Read response
                        byte[] buffer = new byte[MiddlewareMain.FULL_BUFFER_SIZE];
                        int readTotal = 0;
                        int read = streamIn.read(buffer);

                        // If the message from memcached continued
                        while(read != -1) {
                            //log.debug(readTotal + " bytes read");
                            readTotal += read;

                            if(readTotal == 5) {
                                if(buffer[0] == 'E') {// END
                                    break;
                                }
                            }

                            if(readTotal > 0) {
                                if(buffer[readTotal-5] == 'E' && buffer[readTotal-4] == 'N' && buffer[readTotal-3] == 'D') {
                                    break;
                                }
                            }
                            if(streamIn.available() > 0) {
                                read = streamIn.read(buffer);
                            } else {
                                read = 0;
                            }
                        }

                        ByteBuffer wrapped = ByteBuffer.wrap(buffer);
                        log.debug(String.format("Setting buffer limit from %d to %d.", wrapped.limit(), readTotal));
                        wrapped.limit(readTotal);
                        r.setResponseBuffer(wrapped);
                        ResponseFlag responseFlag = Request.getResponseFlag(wrapped);
                        r.setResponseFlag(responseFlag);
                        r.respond();

                        log.debug(String.format("Got response to " + r + ", %d bytes.", readTotal));
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
