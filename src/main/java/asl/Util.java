package main.java.asl;

import java.util.Arrays;
import java.util.Collection;

public class Util {

    /**
     * Turn a byte array into a string.
     */
    public static String bytesToString(byte[] b) {
        StringBuffer sb = new StringBuffer();
        for (int i = 0; i < b.length; ++i) {
            sb.append(Integer.toHexString((b[i] & 0xFF) | 0x100).substring(1,3));
        }
        return sb.toString();
    }

    /**
     * Pretty print a collection.
     */
    public static String collectionToString(Collection c) {
        return Arrays.toString(c.toArray());
    }

    /**
     * Return a string with the escape characters made explicit.
     */
    public static String unEscapeString(String s){
        StringBuilder sb = new StringBuilder();
        for (int i=0; i<s.length(); i++)
            switch (s.charAt(i)){
                case '\n': sb.append("\\n"); break;
                case '\t': sb.append("\\t"); break;
                case '\r': sb.append("\\r"); break;
                // ... rest of escape characters
                default: sb.append(s.charAt(i));
            }
        return sb.toString();
    }

}
