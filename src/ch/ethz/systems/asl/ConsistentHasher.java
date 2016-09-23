package ch.ethz.systems.asl;

import java.util.List;

abstract class ConsistentHasher {

    public abstract Integer hash(String s);

    public abstract List<Integer> getMachines(String s);

}
