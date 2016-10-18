package main.java.asl;

import com.sun.org.apache.bcel.internal.generic.Select;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.SelectionKey;
import java.nio.channels.SocketChannel;

enum RequestType {GET, SET, DELETE, UNKNOWN}

enum ResponseFlag {NA, STORED, NOT_STORED, GET_MISS, GET_SUCCESS, DELETED, DEL_NOT_FOUND, UNKNOWN}

public class Request {

    private static final Logger log = LogManager.getLogger(Request.class);
    private static final Logger csvLog = LogManager.getLogger("request_csv");

    public static final int LOG_SAMPLING_FREQUENCY = 100;

    private RequestType type;
    private ByteBuffer buffer;
    private ByteBuffer responseBuffer;
    private String key;
    private String stringRepresentation;
    private SelectionKey selectionKey;

    private long timeCreated;
    private long timeEnqueued;
    private long timeDequeued;
    private long timeForwarded;
    private long timeReceived;
    private long timeReturned;

    private boolean shouldLog;

    private ResponseFlag responseFlag = ResponseFlag.NA;

    public Request(ByteBuffer buffer, SelectionKey selectionKey) {
        setTimeCreated();
        buffer.flip();
        this.buffer = buffer;
        this.type = getRequestType(buffer);
        this.key = getKeyFromBuffer(buffer);
        this.shouldLog = false;
        this.selectionKey = selectionKey;
    }

    public RequestType getType() {
        return type;
    }

    public String getKey() {
        return key;
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

    public void setTimeReceived() {
        this.timeReceived = System.currentTimeMillis();
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

        ByteBuffer responseBuffer = getResponseBuffer();

        SocketChannel client = (SocketChannel) selectionKey.channel();

        if(Request.isGetMiss(getResponseBuffer())) {
            log.warn("GET miss! " + this);
        }

        // Write buffer
        responseBuffer.rewind();
        int bytesWritten = 0;
        while(responseBuffer.hasRemaining()) {
            int written = client.write(responseBuffer);
            bytesWritten += written;
        }

        setTimeReturned();
        logTimestamps();

        selectionKey.interestOps(SelectionKey.OP_READ);
    }

    /**
     * Find if the request was a get, set, or delete.
     */
    public static RequestType getRequestType(ByteBuffer buffer) {
        char firstChar = (char) buffer.get(0);

        if (firstChar == 's') {
            return RequestType.SET;
        } else if (firstChar == 'g') {
            return RequestType.GET;
        } else if (firstChar == 'd') {
            return RequestType.DELETE;
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
        while(i < buffer.limit()) {
            char c = (char) buffer.get(i);
            if(c == ' ' || c == '\r' || c == '\n') {
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
     * Check if the given DELETE request is complete.
     */
    public static boolean isCompleteDeleteRequest(ByteBuffer buffer) {
        int i = 0;
        int passedSpaces = 0;
        while(i < buffer.limit()) {
            log.debug(String.format("i=%d, passed spaces: %d", i, passedSpaces));
            char c = (char) buffer.get(i);
            if(c == ' ') {
                passedSpaces++;
            } else if(c == '\r' && (passedSpaces == 1 || passedSpaces == 2)) {
                return true;
            }

            i++;
        }
        return false;
    }

    /**
     * Check if buffer contains GET miss message.
     */
    public static boolean isGetMiss(ByteBuffer buffer) {
        String correctString = "END\r\n";
        for(int i=0; i<correctString.length(); i++) {
            if(correctString.charAt(i) != (char) buffer.get(i)) {
                return false;
            }
        }
        return true;
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
            } else if(fifthChar == 'F') {
                return ResponseFlag.DEL_NOT_FOUND;
            }
        } else if(firstChar == 'E') {
            char secondChar = (char) buffer.get(1);
            char thirdChar = (char) buffer.get(2);
            if(secondChar == 'N' && thirdChar == 'D') {
                return ResponseFlag.GET_MISS;
            }
        } else if(firstChar == 'V') {
            return ResponseFlag.GET_SUCCESS;
        } else if(firstChar == 'D') {
            return ResponseFlag.DELETED;
        }
        return ResponseFlag.UNKNOWN;
    }

    /**
     * Write instrumentation timestamps to CSV.
     */
    public void logTimestamps() {
        if(shouldLog) {
            csvLog.info(String.format("%s,%s,%d,%d,%d,%d,%d,%d",
                    type, responseFlag, timeCreated, timeEnqueued, timeDequeued, timeForwarded, timeReceived, timeReturned));
        }
    }

    /**
     * Find if buffer contains any responses and if it does, return the limit of the first one.
     */
    public static Integer firstGetResponseLimit(ByteBuffer buffer) {
        if(buffer.position() >= 8) {            // Minimal answer is "STORED\r\n"
            for(int i=0; i<buffer.position(); i++) {
                if(buffer.get(i) == 0) {
                    return 0;
                }
                char c = (char) buffer.get(i);
                if(c == '\r') {
                    return i + 2;
                }
            }
        }
        return 0;
    }

    @Override
    public String toString() {
        if(stringRepresentation == null) {
            String message = Util.getNonemptyString(buffer);
            stringRepresentation = "'" + key + "' => '" + Util.unEscapeString(message) + "'";
        }
        return stringRepresentation;
    }
}
