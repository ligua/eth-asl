package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.UnsupportedEncodingException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.ArrayList;
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
     * Turn a byte array into a long value.
     */
    public long bytesToLong(byte[] b) {
        return 0;
    }

    /**
     * Hash the given string.
     */
    public byte[] getHash(String s) {
        byte[] hashBytes;
        try {
            hashBytes = md.digest(s.getBytes(encoding));
        } catch (UnsupportedEncodingException ex) {
            String errorString = "Encoding " + encoding + " not available.";
            log.error(errorString);
            throw new RuntimeException(errorString);
        }

        return hashBytes;
    }

    @Override
    public Integer getPrimaryMachine(String s) {
        //byte[] hash = getHash(s);
        Random r = new Random();
        r.setSeed(s.hashCode());

        return r.nextInt(numMachines);
    }

    @Override
    public List<Integer> getAllMachines(String s) {
        Integer primaryMachine = getPrimaryMachine(s);

        List<Integer> allMachines = new ArrayList<>();
        for(int i=0; i<=replicationFactor; i++) {
            allMachines.add((primaryMachine + i) % numMachines);
        }

        return allMachines;
    }

}
