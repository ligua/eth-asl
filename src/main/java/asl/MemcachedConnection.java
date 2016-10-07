package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.Closeable;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintWriter;
import java.net.Socket;
import java.nio.channels.ClosedChannelException;
import java.util.List;

/**
 * One connection with a memcachedSocket instance.
 * Each write thread should have one MemcachedConnection instance *per memcachedSocket server*, so R connections in total.
 * Each read thread should have one MemcachedConnection with its designated memcachedSocket server, so 1 connection in total.
 */
public class MemcachedConnection implements Closeable {

    private static final Logger log = LogManager.getLogger(MemcachedConnection.class);

    public static List<String> memcachedAddresses;

    private String address;
    private Integer port;
    private Socket memcachedSocket;

    public MemcachedConnection(Integer serverNumber) {
        String addressString = memcachedAddresses.get(serverNumber);
        String[] parts = addressString.split(":");
        String address = parts[0];
        Integer port = Integer.parseInt(parts[1]);

        this.address = address;
        this.port = port;

        try {
            memcachedSocket = new Socket(address, port);
        } catch (IOException ex) {
            log.error(ex);
            throw new RuntimeException(ex);
        }
    }


    public void sendRequest(Request r) {
        sendRequest(r, true);
    }

    public void sendRequest(Request r, boolean shouldRespond) {
        try {
            String requestRaw = r.getRequestRaw();

            // Setup socket input and output streams
            PrintWriter socketOut = new PrintWriter(memcachedSocket.getOutputStream(), true);
            InputStream socketIn = memcachedSocket.getInputStream();

            // Send request
            socketOut.write(requestRaw);
            socketOut.flush();
            r.setTimeForwarded();

            // Read response
            String response = "";
            byte[] buffer = new byte[MiddlewareMain.BUFFER_SIZE];
            int read = socketIn.read(buffer);

            // If the message from memcached continued
            while(read != -1) {
                String output = new String(buffer, 0, read);
                log.debug("Response: '" + response + "'");
                response += output;
                log.debug("Response after addition: '" + response + "'");
                if(socketIn.available() > 0) {      // TODO This is probably not a good way to do this?
                    read = socketIn.read(buffer);
                } else {
                    read = -1;
                }
            }

            log.debug("Got response to " + r + ".");

            // Respond if necessary
            if(shouldRespond) {
                try {
                    r.respond(response);
                } catch(ClosedChannelException ex) {
                    log.error("Could not respond to request " + r + ": " + ex);
                }
            }

        } catch (IOException ex) {
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
