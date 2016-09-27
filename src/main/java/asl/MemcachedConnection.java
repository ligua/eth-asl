package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.logging.log4j.core.net.server.InputStreamLogEventBridge;

import java.io.*;
import java.net.Socket;

/**
 * One connection with a memcachedSocket instance.
 * Each write thread should have one MemcachedConnection instance *per memcachedSocket server*, so R connections in total.
 * Each read thread should have one MemcachedConnection with its designated memcachedSocket server, so 1 connection in total.
 */
class MemcachedConnection implements Closeable {

    private static final Logger log = LogManager.getLogger(MemcachedConnection.class);

    private String address;
    private Integer port;
    private Socket memcachedSocket;

    public MemcachedConnection(String address, Integer port) {
        this.address = address;
        this.port = port;

        try {
            memcachedSocket = new Socket(address, port);
        } catch (IOException ex) {
            log.error(ex);
            throw new RuntimeException(ex);
        }

    }

    /**
     * Convenience constructor for development.
     */
    public MemcachedConnection() {
        this("localhost", 11211);
    }


    public void sendRequest(Request r) {
        try {
            String requestRaw = r.getRequestRaw();

            // Setup socket input and output streams
            PrintWriter socketOut = new PrintWriter(memcachedSocket.getOutputStream(), true);
            InputStream socketIn = memcachedSocket.getInputStream();

            log.info("sending req");
            // Send request
            socketOut.write(requestRaw + "\n");
            socketOut.flush();

            r.setTimeForwarded();
            log.info("wrote to socketout");

            String response = "";
            byte[] buffer = new byte[1024];     // TODO how big buffer do I need?
            int read = socketIn.read(buffer);
            while(read != -1) {
                String output = new String(buffer, 0, read);
                log.info("still shit coming in from socket: " + output);
                response += output;
                log.info("shit came in from socket: " + output);
                if(socketIn.available() > 0) {      // TODO This is probably not a good way to do this?
                    read = socketIn.read(buffer);
                } else {
                    log.info("stream done");
                    read = -1;
                }
            }
            log.info("got response");

            r.respond("Response to " + r + ": " + response);
        } catch (IOException ex) {
            System.out.println("fuck" + ex);
            log.error(ex);
            throw new RuntimeException(ex);
        }
    }


    @Override
    public void close() {
        try {
            memcachedSocket.close();
        } catch (IOException ex) {
            log.error(ex);
            throw new RuntimeException(ex);
        }
    }

}
