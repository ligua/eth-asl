package ch.ethz.systems.asl;

import java.util.List;

public class ConsistentHasherImpl extends ConsistentHasher {

    private Integer numMachines;


    ConsistentHasherImpl(Integer numMachines) {
        this.numMachines = numMachines;
    }

    @Override
    public Integer hash(String s) {
        // TODO
        return 0;
    }

    @Override
    public Integer getPrimaryMachine(String s) {
        return null;
    }

    @Override
    public List<Integer> getAllMachines(String s) {
        // TODO
        return null;
    }

}
