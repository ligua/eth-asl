package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.nio.channels.SocketChannel;
import java.util.Date;

enum RequestType {GET, SET, UNKNOWN}

public class Request {

    private static final Logger log = LogManager.getLogger(Request.class);

    private RequestType type;
    private String requestRaw;
    private String key;
    private SocketChannel client;

    private boolean hasResponse;
    private String response;

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

    public boolean hasResponse() {
        return hasResponse;
    }

    public String getResponse() {
        return response;
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
        this.response = response;
        this.hasResponse = true;
/*
        ByteBuffer buffer = ByteBuffer.allocate(256);       // TODO is this buffer big enough? (check max message size)

        // Populate buffer
        buffer.put(response.getBytes());
        buffer.flip();

        log.debug("Trying to respond to client " + client);

        // Write buffer
        while(buffer.hasRemaining()) {
            client.write(buffer);

            int result = client.write(buffer);
            log.debug("Responding to request " + this + ": writing '" + Util.unEscapeString(response) + "'; result: " + result);
        }


        setTimeReturned();

        log.debug(String.format("Request took %dms to forward, %dms to return response.",
                timeForwarded.getTime()-timeCreated.getTime(), timeReturned.getTime()-timeCreated.getTime()));

        // Close connection
        client.close();     // TODO should I close anything else?*/
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
        } else {
            return RequestType.UNKNOWN;
        }
    }

    /**
     * Check if the given SET request is complete.
     */
    public static boolean isCompleteSetRequest(String request) {
        String[] lines = request.split("\\r?\\n");
        if(lines.length < 2) {
            return false;
        } else {
            String firstLine = lines[0];
            String secondLine = lines[1];
            String[] firstLineParts = firstLine.split("\\s+");
            Integer numCharsDeclared = Integer.parseInt(firstLineParts[4]);
            Integer numCharsActual = secondLine.length();

            return numCharsActual >= numCharsDeclared;
        }
    }


    @Override
    public String toString() {
        return "'" + Util.unEscapeString(this.requestRaw) + "'";
    }
}
