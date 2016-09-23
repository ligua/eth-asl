package ch.ethz.systems.asl;

import ch.ethz.systems.asl.justtesting.CrunchifyNIOServer;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.util.List;

public class ConsistentHasherImpl implements ConsistentHasher {

    private static final Logger log = LogManager.getLogger(ConsistentHasherImpl.class);

    private Integer numMachines;
    private Integer replicationFactor;


    ConsistentHasherImpl(Integer numMemcachedServers, Integer replicationFactor) {
        if(replicationFactor > numMemcachedServers) {
            throw new RuntimeException("Replication factor cannot be larger than the number of machines!");
        }
        this.numMachines = numMemcachedServers;
        this.replicationFactor = replicationFactor;


        log.info("Hasher initialised.");
    }

    @Override
    public Integer hash(String s) {
        // TODO
        return 0;
    }

    @Override
    public Integer getPrimaryMachine(String s) {
        // TODO
        return 0;
    }

    @Override
    public List<Integer> getAllMachines(String s) {
        // TODO
        return null;
    }

}
