package ch.ethz.systems.asl;

import java.util.List;

abstract class ConsistentHasher {

    public abstract Integer hash(String s);

    public abstract Integer getPrimaryMachine(String s);

    public abstract List<Integer> getAllMachines(String s);

}
