package main.java.asl;

import com.sun.org.apache.bcel.internal.generic.Select;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.nio.channels.SocketChannel;
import java.nio.charset.CharacterCodingException;
import java.util.Date;

enum RequestType {GET, SET, DELETE, UNKNOWN};

public class Request {

    private static final Logger log = LogManager.getLogger(Request.class);

    private RequestType type;
    private String requestRaw;
    private String key;
    private SocketChannel client;

    private Date timeCreated;
    private Date timeForwarded;
    private Date timeReturned;

    public Request(String request, SocketChannel client) {
        setTimeCreated();
        this.requestRaw = request;
        this.client = client;
        type = getRequestType(request);
        key = requestRaw.split("\\s+", 3)[1];
    }

    public RequestType getType() {
        return type;
    }

    public String getRequestRaw() {
        return requestRaw;
    }

    public String getKey() {
        return key;
    }

    private void setTimeCreated() {
        this.timeCreated = new Date();
    }

    void setTimeForwarded() {
        this.timeForwarded = new Date();
    }

    private void setTimeReturned() {
        this.timeReturned = new Date();
    }

    /**
     * Respond to the request and close connection.
     */
    public void respond(String response) throws IOException {

        ByteBuffer buffer = ByteBuffer.allocate(256);       // TODO is this buffer big enough? (check max message size)

        // Populate buffer
        buffer.put(response.getBytes());
        buffer.flip();

        // Write buffer
        while(buffer.hasRemaining()) {
            client.write(buffer);

            int result = client.write(buffer);
            log.debug("Responding to request " + this + ": writing '" + response + "'; result: " + result);
        }

        setTimeReturned();

        log.debug(String.format("Request took %dms to forward, %dms to return response.",
                timeForwarded.getTime()-timeCreated.getTime(), timeReturned.getTime()-timeCreated.getTime()));

        // Close connection
        client.close();     // TODO should I close anything else?
    }

    /**
     * Find if the requestRaw was a get, set or delete requestRaw.
     */
    public static RequestType getRequestType(String request) {
        String firstThreeChars = request.substring(0, 3);

        if (firstThreeChars.equals("set")) {
            return RequestType.SET;
        } else if (firstThreeChars.equals("get")) {
            return RequestType.GET;
        } else if (firstThreeChars.equals("del")) {
            return RequestType.DELETE;
        } else {
            return RequestType.UNKNOWN;
        }
    }


    @Override
    public String toString() {
        return "'" + this.requestRaw + "'";
    }
}
