package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.SocketChannel;
import java.util.Date;

enum RequestType {GET, SET, UNKNOWN}

public class Request {

    private static final Logger log = LogManager.getLogger(Request.class);
    private static final Logger csvLog = LogManager.getLogger("request_csv");

    public static final int LOG_SAMPLING_FREQUENCY = 100;

    private RequestType type;
    private ByteBuffer buffer;
    private String requestText;
    private String key;
    private SocketChannel client;

    private boolean hasResponse;
    private String response;

    private long timeCreated;
    private long timeEnqueued;
    private long timeDequeued;
    private long timeForwarded;
    private long timeReturned;

    private boolean shouldLog;

    private String successFlag = "N/A";

    public Request(ByteBuffer buffer, SocketChannel client) {
        setTimeCreated();
        buffer.flip();
        this.buffer = buffer;
        this.client = client;
        type = getRequestType(buffer);
        String message = new String(buffer.array());
        requestText = message.substring(0, buffer.position());
        key = getKeyFromBuffer(buffer);
        shouldLog = false;
    }

    public RequestType getType() {
        return type;
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
        this.timeCreated = System.currentTimeMillis();
    }

    public void setTimeEnqueued() {
        this.timeEnqueued = System.currentTimeMillis();
    }

    public void setTimeDequeued() {
        this.timeDequeued = System.currentTimeMillis();
    }

    void setTimeForwarded() {
        this.timeForwarded = System.currentTimeMillis();
    }

    public void setTimeReturned() {
        this.timeReturned = System.currentTimeMillis();
    }

    public void setShouldLog(boolean shouldLog) {
        this.shouldLog = shouldLog;
    }

    public ByteBuffer getBuffer() {
        return buffer;
    }

    /**
     * Respond to the request and close connection.
     */
    public void respond(String response) throws IOException {
        this.response = response;
        log.debug("RESPONDING WITH '" + response + "'");
        this.hasResponse = true;
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
     * Find if the request was a get or set.
     */
    public static RequestType getRequestType(ByteBuffer buffer) {
        char firstChar = (char) buffer.get(0);

        if (firstChar == 's') {
            return RequestType.SET;
        } else if (firstChar == 'g') {
            return RequestType.GET;
        } else {
            return RequestType.UNKNOWN;
        }
    }

    /**
     * Get the key from a buffer.
     */
    public static String getKeyFromBuffer(ByteBuffer buffer) {
        // TODO write tests for this method
        String key = "";
        int i = 4;  // We know the first 4 chars are 'get ' or 'set '
        while(i < buffer.position()) {
            char c = (char) buffer.get(i);
            if(c == ' ') {
                break;
            }
            key += c;
            i++;
        }
        return key;
    }


    /**
     * Check if the given SET request is complete.
     */
    public static boolean isCompleteSetRequest(ByteBuffer buffer) {
        int i = 0;
        int newLineStart = Integer.MAX_VALUE;
        int bufferPosition = buffer.position();
        int passedSpaces = 0;
        String messageLengthString = "";
        while(i < buffer.limit()) {
            char c = (char) buffer.get(i);
            log.debug("char: '" + c + "'");
            i++;

            if(c == ' ') {
                passedSpaces++;
                continue;
            }

            if(c == '\n') {
                newLineStart = i + 1;
                break;
            }

            log.debug("passed spaces: " + passedSpaces);
            if(passedSpaces == 4) {
                messageLengthString += c;
            }
            log.debug("messageLengthString: " + messageLengthString.trim());


        }
        int declaredValueLength = Integer.parseInt(messageLengthString.trim());
        log.debug("Bufferposition: " + bufferPosition + ", newLineStart: " + newLineStart);
        int actualValueLength = bufferPosition - newLineStart; // TODO buffer.limit() is 2048, what else can I get? :(

        if (declaredValueLength == actualValueLength -1 ) { // Subtract 1 because there's also a newline
            return true;
        }

        log.debug(String.format("Declared %d chars in message, got %d.", declaredValueLength, actualValueLength));
        return false;
        /*
        String message = new String(buffer.array());
        message = message.substring(0, buffer.position());

        String[] lines = message.split("\\r?\\n");
        if(lines.length < 2) {
            return false;
        } else {
            String firstLine = lines[0];
            String secondLine = lines[1];
            String[] firstLineParts = firstLine.split("\\s+");
            Integer numCharsDeclared = Integer.parseInt(firstLineParts[4]);
            Integer numCharsActual = secondLine.length();

            return numCharsActual >= numCharsDeclared;
        }*/
    }

    /**
     * Write instrumentation timestamps to CSV.
     */
    public void logTimestamps() {
        if(shouldLog) {
            csvLog.info(String.format("%s,%s,%d,%d,%d,%d,%d",
                    type, successFlag, timeCreated, timeEnqueued, timeDequeued, timeForwarded, timeReturned));
        }
    }


    @Override
    public String toString() {
        String message = new String(buffer.array());
        message = message.substring(0, buffer.position());
        return "'" + Util.unEscapeString(message) + "'";
    }
}
