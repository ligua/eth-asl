package ch.ethz.systems.asl;

import java.util.List;

public class ConsistentHasherImpl implements ConsistentHasher {

    private Integer numMachines;
    private Integer replicationFactor;


    ConsistentHasherImpl(Integer numMemcachedServers, Integer replicationFactor) {
        if(replicationFactor > numMemcachedServers) {
            throw new RuntimeException("Replication factor cannot be larger than the number of machines!");
        }
        this.numMachines = numMemcachedServers;
        this.replicationFactor = replicationFactor;
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
