package main.java.asl;

enum RequestType { GET, SET, DELETE };

public class Request {
    public RequestType type;
    public String requestRaw;
    public String key;
    public String response;

    public Request(String request) {
        this.requestRaw = request;
        type = getRequestType(request);
        // TODO parse the requestRaw key and message etc
    }

    /**
     * Parse requestRaw and return appropriate type of requestRaw.
     */


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
            throw new RuntimeException("Unknown requestRaw: " + request);
        }
    }
}
