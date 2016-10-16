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

    public UniformHasher(Integer numMemcachedServers, Integer replicationFactor) {
        if(replicationFactor > numMemcachedServers) {
            throw new RuntimeException("Replication factor cannot be larger than the number of machines!");
        }
        this.numMachines = numMemcachedServers;
        this.replicationFactor = replicationFactor;

        log.info("Hasher initialised.");
    }


    /**
     * Get the primary machine corresponding to a key.
     * @param s the key of a request.
     * @return Machine ID: integer in [0, numMachines).
     */
    @Override
    public Integer getPrimaryMachine(String s) {
        Random r = new Random();
        r.setSeed(s.hashCode());

        return r.nextInt(numMachines);
    }

    /**
     * Get the all machines we need to replicate to given a key.
     * @param primaryMachine the primary machine for the key.
     * @return A list of all machines we need to replicate to, including primaryMachine as the first element.
     */
    @Override
    public List<Integer> getTargetMachines(Integer primaryMachine) {
        return getTargetMachines(primaryMachine, replicationFactor, numMachines);
    }

    private static List<Integer> getTargetMachines(Integer primaryMachine, Integer replicationFactor, Integer numMachines) {

        List<Integer> allMachines = new ArrayList<>();
        //allMachines.add(primaryMachine);
        for(int i=0; i<replicationFactor; i++) {
            allMachines.add((primaryMachine + i) % numMachines);
        }

        return allMachines;
    }

}
