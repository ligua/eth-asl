package main.java.asl;

import java.nio.ByteBuffer;
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

    /**
     * Count the number of non-empty bytes in a buffer.
     */
    public static Integer getNumNonemptyBytes(ByteBuffer buffer) {
        Integer counter = 0;

        for(int i=0; i<buffer.limit(); i++) {
            byte b = buffer.get(i);
            if(b > 0) {
                counter++;
            } else {
                break;
            }
        }
        return counter;
    }

    /**
     * Make a string out of a buffer, ignoring empty bytes.
     */
    public static String getNonemptyString(ByteBuffer buffer) {
        String s = "";
        for(int i=0; i<buffer.limit(); i++) {
            if(buffer.get(i) != 0) {
                s += (char) buffer.get(i);
            }
        }

        return s;
    }

    /**
     * Get the first line from a buffer.
     */
    public static String getFirstLine(ByteBuffer buffer) {
        String line = "";
        for(int i=0; i<buffer.limit(); i++) {
            char c = (char) buffer.get(i);
            if(c == '\n' || c == '\r') {
                break;
            } else {
                line += c;
            }
        }
        return line;
    }

    /**
     * Copy the contents of the buffer from [offset, offset + count] to [0, count] and set everything else to 0.
     */
    public static void copyToBeginning(ByteBuffer buffer, int offset, int count) {
        byte[] array = buffer.array();
        for(int i=0; i<offset+count; i++) {
            if(offset + i > buffer.capacity() - 1) {
                array[i] = 0;
            } else if(i < count) {
                array[i] = array[offset + i];
            } else {
                array[i] = 0;
            }
        }
    }

}
