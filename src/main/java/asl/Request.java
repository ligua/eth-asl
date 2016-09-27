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

enum RequestType {GET, SET, DELETE, UNKNOWN};

public class Request {

    private static final Logger log = LogManager.getLogger(Request.class);

    private RequestType type;
    private String requestRaw;
    private String key;
    private SocketChannel client;

    public Request(String request, SocketChannel client) {
        this.requestRaw = request;
        this.client = client;
        type = getRequestType(request);
        // TODO parse the requestRaw key
        key = "fookey";
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

    /**
     * Respond to the request and close connection.
     */
    public void respond(String response) throws IOException {

        Selector selector = Selector.open();
        SelectionKey selectionKey = client.register(selector, SelectionKey.OP_WRITE);
        log.info("Valid operations: " + client.validOps());


        ByteBuffer buffer = ByteBuffer.allocate(256);       // TODO is this buffer big enough? (check max message size)

        // Populate buffer
        //buffer.putInt(response.length());
        buffer.put(response.getBytes());
        buffer.flip();

        // Write buffer
        while(buffer.hasRemaining()) {
            client.write(buffer);

            int result = client.write(buffer);
            log.info("Responding to request " + this + ": writing '" + response + "'; result: " + result);
        }

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
