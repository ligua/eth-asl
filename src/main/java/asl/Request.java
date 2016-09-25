package main.java.asl;

enum RequestType { GET, SET, DELETE };

public class Request {
    public RequestType type;
    public String key;


    public Request(String request) {
        type = getRequestType(request);
        // TODO parse the request key and message etc
    }

    /**
     * Parse request and return appropriate type of request.
     */


    /**
     * Find if the request was a get, set or delete request.
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
            throw new RuntimeException("Unknown request: " + request);
        }
    }
}
