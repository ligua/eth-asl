package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.UnsupportedEncodingException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.List;
import java.util.Random;

public class UniformHasher implements Hasher {

    private static final Logger log = LogManager.getLogger(UniformHasher.class);

    private Integer numMachines;
    private Integer replicationFactor;

    private String hashingAlgorithm = "MD5";
    private String encoding = "UTF-8";

    private MessageDigest md;


    public UniformHasher(Integer numMemcachedServers, Integer replicationFactor) {
        if(replicationFactor > numMemcachedServers) {
            throw new RuntimeException("Replication factor cannot be larger than the number of machines!");
        }
        this.numMachines = numMemcachedServers;
        this.replicationFactor = replicationFactor;

        try {
            this.md = MessageDigest.getInstance(hashingAlgorithm);
        } catch (NoSuchAlgorithmException ex) {
            String errorString = "Hashing algorithm " + hashingAlgorithm + " not found in MessageDigest class.";
            log.error(errorString);
            throw new RuntimeException(errorString);
        }


        log.info("Hasher initialised.");
    }

    /**
     * Turn a byte array into a string.
     */
    public String bytesToString(byte[] b) {
        StringBuffer sb = new StringBuffer();
        for (int i = 0; i < b.length; ++i) {
            sb.append(Integer.toHexString((b[i] & 0xFF) | 0x100).substring(1,3));
        }
        return sb.toString();
    }

    /**
     * Hash the given string.
     */
    public String getHash(String s) {
        String hash;
        try {
            byte[] hashBytes = md.digest(s.getBytes(encoding));
            hash = bytesToString(hashBytes);
        } catch (UnsupportedEncodingException ex) {
            String errorString = "Encoding " + encoding + " not available.";
            log.error(errorString);
            throw new RuntimeException(errorString);
        }

        return hash;
    }

    @Override
    public Integer getPrimaryMachine(String s) {
        String hash = getHash(s);

        //Random r = new Random(hash);

        return 0;
    }

    @Override
    public List<Integer> getAllMachines(String s) {
        // TODO
        return null;
    }

}
