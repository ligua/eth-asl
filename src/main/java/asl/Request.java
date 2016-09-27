package main.java.asl;

import com.sun.org.apache.bcel.internal.generic.Select;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
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
    private SelectionKey selectionKey;

    public Request(String request, SelectionKey selectionKey) {
        this.requestRaw = request;
        this.selectionKey = selectionKey;
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
     * Respond to the request.
     */
    public void respond(String response) throws IOException {

        Selector selector = Selector.open();
        SocketChannel client = (SocketChannel) selectionKey.channel();
        SelectionKey newSelectionKey = client.register(selector, SelectionKey.OP_WRITE);
        client = (SocketChannel) newSelectionKey.channel();
        log.info("Valid operations: " + client.validOps());

        if (true) {

            //selectionKey = client.register(selector, SelectionKey.OP_WRITE);
            ByteBuffer buffer = ByteBuffer.allocate(256);

            // Populate buffer
            buffer.putInt(response.length());
            buffer.put(response.getBytes());
            buffer.flip();

            // Write buffer
            while(buffer.hasRemaining()) {
                client.write(buffer);

                int result = client.write(buffer);
                log.info("Responding to request " + this + ": writing '" + response + "'; result: " + result);
            }

            client.close();
            // TODO also close connection?

        } else {
            throw new RuntimeException("Selection key for request " + this + " is not writable.");
        }
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
