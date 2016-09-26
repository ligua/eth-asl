package main.java.asl;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.SelectionKey;
import java.nio.channels.SocketChannel;
import java.nio.charset.CharacterCodingException;

enum RequestType { GET, SET, DELETE, UNKNOWN };

public class Request {
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
    public void respond(String response) {
        if(selectionKey.isWritable()) {
            SocketChannel client = (SocketChannel) selectionKey.channel();
            ByteBuffer buffer = ByteBuffer.allocate(256);
            // TODO Populate buffer
            buffer.putInt(response.length());
            buffer.put(response.getBytes());

            try {
                client.write(buffer);
                // TODO also close connection?
            } catch(IOException ex) {
                throw new RuntimeException(ex);
            }
        } else {
            throw new RuntimeException("Selection key for request " + this + " is not writable.");
        }
    }

    /**
     * Find if the requestRaw was a get, set or delete requestRaw.
     */
    public static RequestType getRequestType(String request) {
        String firstThreeChars = request.substring(0, 3);

        if(firstThreeChars.equals("set")) {
            return RequestType.SET;
        } else if(firstThreeChars.equals("get")) {
            return RequestType.GET;
        } else if(firstThreeChars.equals("del")) {
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
