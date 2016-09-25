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

}
