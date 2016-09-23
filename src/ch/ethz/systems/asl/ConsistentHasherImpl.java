package ch.ethz.systems.asl;

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

}
