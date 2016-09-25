package main.java.asl;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.UnsupportedEncodingException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
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
        if(replicationFactor >= numMemcachedServers) {
            throw new RuntimeException("Replication factor cannot be larger than or equal to the number of machines!");
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
        Random r = new Random();
        r.setSeed(s.hashCode());

        return r.nextInt(numMachines);
    }

    @Override
    public List<Integer> getTargetMachines(Integer primaryMachine) {
        return getTargetMachines(primaryMachine, replicationFactor, numMachines);
    }

    public static List<Integer> getTargetMachines(Integer primaryMachine, Integer replicationFactor, Integer numMachines) {

        List<Integer> allMachines = new ArrayList<>();
        allMachines.add(primaryMachine);
        for(int i=1; i<=replicationFactor; i++) {
            allMachines.add((primaryMachine + i) % numMachines);
        }

        return allMachines;
    }

}
