package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.SocketChannel;

enum RequestType {GET, SET, UNKNOWN}

enum ResponseFlag {NA, STORED, NOT_STORED, GET_MISS, UNKNOWN}

public class Request {

    private static final Logger log = LogManager.getLogger(Request.class);
    private static final Logger csvLog = LogManager.getLogger("request_csv");

    public static final int LOG_SAMPLING_FREQUENCY = 1;

    private RequestType type;
    private ByteBuffer buffer;
    private ByteBuffer responseBuffer;
    private String key;

    private boolean hasResponse;

    private long timeCreated;
    private long timeEnqueued;
    private long timeDequeued;
    private long timeForwarded;
    private long timeReturned;

    private boolean shouldLog;

    private ResponseFlag responseFlag = ResponseFlag.NA;

    public Request(ByteBuffer buffer, SocketChannel client) {
        setTimeCreated();
        buffer.flip();
        this.buffer = buffer;
        type = getRequestType(buffer);
        String message = new String(buffer.array());
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

    public ByteBuffer getResponseBuffer() {
        return responseBuffer;
    }

    public ByteBuffer getBuffer() {
        return buffer;
    }

    public ResponseFlag getResponseFlag() {
        return responseFlag;
    }

    public void setResponseFlag(ResponseFlag responseFlag) {
        this.responseFlag = responseFlag;
    }

    public void setResponseBuffer(ByteBuffer responseBuffer) {
        this.responseBuffer = responseBuffer;
    }

    /**
     * Respond to the request.
     */
    public void respond() throws IOException {
        if(this.responseBuffer == null) {
            throw new RuntimeException("Can't respond with an empty buffer!");
        }
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
            //log.debug("char: '" + c + "'");
            i++;

            if(c == ' ') {
                passedSpaces++;
                continue;
            }

            if(c == '\n') {
                newLineStart = i + 1;
                break;
            }

            //log.debug("passed spaces: " + passedSpaces);
            if(passedSpaces == 4) {
                messageLengthString += c;
            }
            //log.debug("messageLengthString: " + messageLengthString.trim());


        }
        int declaredValueLength = Integer.parseInt(messageLengthString.trim());
        //log.debug("Bufferposition: " + bufferPosition + ", newLineStart: " + newLineStart);
        int actualValueLength = bufferPosition - newLineStart; // TODO buffer.limit() is 2048, what else can I get? :(

        if (declaredValueLength == actualValueLength -1 ) { // Subtract 1 because there's also a newline
            return true;
        }

        log.debug(String.format("Declared %d chars in message, got %d.", declaredValueLength, actualValueLength));
        return false;
    }

    /**
     * Get the response flag, given a set-request response buffer.
     */
    public static ResponseFlag getResponseFlag(ByteBuffer buffer) {
        char firstChar = (char) buffer.get(0);
        char fifthChar = (char) buffer.get(4);
        if(firstChar == 'S') {
            return ResponseFlag.STORED;
        } else if(firstChar == 'N') {
            if(fifthChar == 'S') {
                return ResponseFlag.NOT_STORED;
            }
        } else if(firstChar == 'E') {
            char secondChar = (char) buffer.get(1);
            char thirdChar = (char) buffer.get(2);
            if(secondChar == 'N' && thirdChar == 'D') {
                return ResponseFlag.GET_MISS;
            }
        }
        return ResponseFlag.UNKNOWN;
    }

    /**
     * Write instrumentation timestamps to CSV.
     */
    public void logTimestamps() {
        if(shouldLog) {
            csvLog.info(String.format("%s,%s,%d,%d,%d,%d,%d",
                    type, responseFlag, timeCreated, timeEnqueued, timeDequeued, timeForwarded, timeReturned));
        }
    }


    @Override
    public String toString() {
        String message = new String(buffer.array());
        message = message.trim();
        return "'" + Util.unEscapeString(message) + "'";
    }
}
