package main.java.asl;

import java.util.List;

interface ConsistentHasher {

    public abstract Integer hash(String s);

    public abstract Integer getPrimaryMachine(String s);

    public abstract List<Integer> getAllMachines(String s);

}
