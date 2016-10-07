package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.IOException;
import java.nio.channels.SocketChannel;
import java.util.Date;

enum RequestType {GET, SET, UNKNOWN}

public class Request {

    private static final Logger log = LogManager.getLogger(Request.class);
    private static final Logger csvLog = LogManager.getLogger("request_csv");

    public static final int LOG_SAMPLING_FREQUENCY = 100;

    private RequestType type;
    private String requestRaw;
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

    public Request(String request, SocketChannel client) {
        setTimeCreated();
        this.requestRaw = request;
        this.client = client;
        type = getRequestType(request);
        key = requestRaw.split("\\s+", 3)[1];
        shouldLog = false;
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
        return "'" + Util.unEscapeString(this.requestRaw) + "'";
    }
}
