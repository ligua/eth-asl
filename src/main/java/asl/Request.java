package main.java.asl;

enum RequestType { GET, SET, DELETE, UNKNOWN };

public class Request {
    private RequestType type;
    private String requestRaw;
    private String key;
    private String response;

    public Request(String request) {
        this.requestRaw = request;
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

    public String getResponse() {
        return response;
    }

    public void setResponse(String response) {
        this.response = response;
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
